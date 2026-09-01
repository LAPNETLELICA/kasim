import json
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import BrowserResource, AIResource, User
from app.schemas import (
    BrowserResourceCreate, BrowserResourceResponse,
    AIResourceCreate, AIResourceResponse
)
from app.security import get_current_user


router = APIRouter(prefix="/api/resources", tags=["Resource Registry"])


def seed_default_resources_if_needed(db: Session):
    """Compatibility shim retained for older callers.

    Kasim intentionally has no built-in browser or AI catalogue. Every
    resource is supplied by a lecturer or registered while creating a session.
    """
    return None


@router.get("/browsers", response_model=List[BrowserResourceResponse])
def get_browser_resources(db: Session = Depends(get_db)):
    seed_default_resources_if_needed(db)
    browsers = db.query(BrowserResource).all()
    res = []
    for b in browsers:
        res.append(BrowserResourceResponse(
            id=b.id,
            name=b.name,
            executables=json.loads(b.executables) if isinstance(b.executables, str) else b.executables,
            description=b.description,
            is_custom=b.is_custom,
            created_at=b.created_at
        ))
    return res


@router.post("/browsers", response_model=BrowserResourceResponse, status_code=status.HTTP_201_CREATED)
def create_browser_resource(
    resource_in: BrowserResourceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "lecturer":
        raise HTTPException(status_code=403, detail="Only lecturers can register custom browser resources")

    existing = db.query(BrowserResource).filter(BrowserResource.name.ilike(resource_in.name)).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"Browser resource with name '{resource_in.name}' already exists")

    new_b = BrowserResource(
        name=resource_in.name,
        executables=json.dumps(resource_in.executables),
        description=resource_in.description,
        is_custom=True
    )
    db.add(new_b)
    db.commit()
    db.refresh(new_b)

    return BrowserResourceResponse(
        id=new_b.id,
        name=new_b.name,
        executables=resource_in.executables,
        description=new_b.description,
        is_custom=True,
        created_at=new_b.created_at
    )


@router.get("/ai-services", response_model=List[AIResourceResponse])
def get_ai_resources(db: Session = Depends(get_db)):
    seed_default_resources_if_needed(db)
    ai_list = db.query(AIResource).all()
    res = []
    for a in ai_list:
        res.append(AIResourceResponse(
            id=a.id,
            name=a.name,
            domains=json.loads(a.domains) if isinstance(a.domains, str) else a.domains,
            desktop_executables=json.loads(a.desktop_executables) if isinstance(a.desktop_executables, str) else a.desktop_executables,
            description=a.description,
            is_custom=a.is_custom,
            created_at=a.created_at
        ))
    return res


@router.post("/ai-services", response_model=AIResourceResponse, status_code=status.HTTP_201_CREATED)
def create_ai_resource(
    resource_in: AIResourceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "lecturer":
        raise HTTPException(status_code=403, detail="Only lecturers can register custom AI resources")

    existing = db.query(AIResource).filter(AIResource.name.ilike(resource_in.name)).first()
    if existing:
        raise HTTPException(status_code=400, detail=f"AI resource with name '{resource_in.name}' already exists")

    new_ai = AIResource(
        name=resource_in.name,
        domains=json.dumps(resource_in.domains),
        desktop_executables=json.dumps(resource_in.desktop_executables),
        description=resource_in.description,
        is_custom=True
    )
    db.add(new_ai)
    db.commit()
    db.refresh(new_ai)

    return AIResourceResponse(
        id=new_ai.id,
        name=new_ai.name,
        domains=resource_in.domains,
        desktop_executables=resource_in.desktop_executables,
        description=new_ai.description,
        is_custom=True,
        created_at=new_ai.created_at
    )
