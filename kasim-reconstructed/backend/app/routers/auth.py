import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.database import get_db
from app import models, schemas, security

router = APIRouter(prefix="/api/auth", tags=["Authentication"])


@router.post("/register", response_model=schemas.UserResponse, status_code=status.HTTP_201_CREATED)
def register_user(user_in: schemas.UserCreate, db: Session = Depends(get_db)):
    # Check if username or email exists
    existing_user = db.query(models.User).filter(
        (models.User.username == user_in.username) | (models.User.email == user_in.email)
    ).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username or Email already registered"
        )
    
    hashed_pwd = security.get_password_hash(user_in.password)
    user = models.User(
        username=user_in.username,
        email=user_in.email,
        hashed_password=hashed_pwd,
        auth_provider="password",
        role=user_in.role
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.post("/login", response_model=schemas.Token)
def login_json(login_req: schemas.LoginRequest, db: Session = Depends(get_db)):
    ident = (login_req.identifier or login_req.username or "").strip()
    if not ident:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email or Platform Name is required",
        )

    # Resolve by email or username (case-insensitive for email, case-insensitive/exact for username)
    user = db.query(models.User).filter(
        (models.User.email.ilike(ident)) | (models.User.username.ilike(ident))
    ).first()

    if not user or not security.verify_password(login_req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect Email/Platform Name or Password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = security.create_access_token(data={"sub": user.username, "role": user.role, "user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }


@router.post("/token", response_model=schemas.Token)
def login_form(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    ident = form_data.username.strip()
    user = db.query(models.User).filter(
        (models.User.email.ilike(ident)) | (models.User.username.ilike(ident))
    ).first()
    if not user or not security.verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect Email/Platform Name or Password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = security.create_access_token(data={"sub": user.username, "role": user.role, "user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }


@router.post("/google", response_model=schemas.Token)
def google_auth(google_req: schemas.GoogleLoginRequest, db: Session = Depends(get_db)):
    client_id = os.getenv("GOOGLE_CLIENT_ID", "").strip()
    if not client_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Google sign-in is not configured. Set GOOGLE_CLIENT_ID on the API server.",
        )

    try:
        from google.auth.transport import requests as google_requests
        from google.oauth2 import id_token

        claims = id_token.verify_oauth2_token(
            google_req.credential,
            google_requests.Request(),
            client_id,
        )
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google identity token could not be verified",
        ) from exc

    email = str(claims.get("email", "")).strip().lower()
    if not email or not claims.get("email_verified"):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Google account must have a verified email address",
        )

    display_name = str(claims.get("name") or email.split("@")[0]).strip()
    user = db.query(models.User).filter(models.User.email == email).first()

    if not user:
        # Auto-create user for Google sign-in/registration
        username = display_name
        # Ensure username uniqueness
        existing_username = db.query(models.User).filter(models.User.username.ilike(username)).first()
        if existing_username:
            username = f"{username}_{uuid.uuid4().hex[:4]}"

        random_password = security.get_password_hash(uuid.uuid4().hex)
        user = models.User(
            username=username,
            email=email,
            hashed_password=random_password,
            auth_provider="google",
            role="lecturer"
        )
        db.add(user)
        db.commit()
        db.refresh(user)

    access_token = security.create_access_token(data={"sub": user.username, "role": user.role, "user_id": user.id})
    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": user
    }


@router.get("/me", response_model=schemas.UserResponse)
def read_current_user(current_user: models.User = Depends(security.get_current_user)):
    return current_user


@router.patch("/profile", response_model=schemas.UserResponse)
def update_profile(
    profile_in: schemas.UserProfileUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(security.get_current_user),
):
    if profile_in.name:
        duplicate = db.query(models.User).filter(
            models.User.username.ilike(profile_in.name),
            models.User.id != current_user.id,
        ).first()
        if duplicate:
            raise HTTPException(status_code=400, detail="That profile name is already in use")
        current_user.username = profile_in.name.strip()

    if profile_in.new_password:
        if current_user.auth_provider == "password":
            if not profile_in.current_password or not security.verify_password(
                profile_in.current_password,
                current_user.hashed_password,
            ):
                raise HTTPException(status_code=400, detail="Current password is incorrect")
        current_user.hashed_password = security.get_password_hash(profile_in.new_password)
        current_user.auth_provider = (
            "google+password" if "google" in current_user.auth_provider else "password"
        )

    db.commit()
    db.refresh(current_user)
    return current_user
