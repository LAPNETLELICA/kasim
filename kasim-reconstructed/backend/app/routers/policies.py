import json
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import AccessPolicy, BrowserResource, AIResource, User
from app.schemas import (
    AccessPolicyCreate, AccessPolicyResponse,
    PolicyPreviewResponse, SignedPolicyPayload
)
from app.security import get_current_user
from app.policy_engine import (
    create_signed_policy_payload, generate_policy_preview, generate_policy_signature
)


router = APIRouter(prefix="/api/policies", tags=["Policies"])


def parse_policy_response(p: AccessPolicy) -> AccessPolicyResponse:
    allowed_browsers = json.loads(p.allowed_browsers) if isinstance(p.allowed_browsers, str) else p.allowed_browsers
    allowed_ai = json.loads(p.allowed_ai) if isinstance(p.allowed_ai, str) else p.allowed_ai
    matrix = json.loads(p.browser_ai_matrix) if isinstance(p.browser_ai_matrix, str) else p.browser_ai_matrix
    allowed_desktop_apps = json.loads(p.allowed_desktop_apps) if isinstance(p.allowed_desktop_apps, str) else p.allowed_desktop_apps

    return AccessPolicyResponse(
        id=p.id,
        title=p.title,
        description=p.description,
        version=p.version,
        default_action=p.default_action,
        policy_mode=p.policy_mode,
        browser_mode=p.browser_mode,
        ai_mode=p.ai_mode,
        web_access_scope=p.web_access_scope,
        desktop_app_mode=p.desktop_app_mode,
        allowed_browsers=allowed_browsers,
        allowed_ai=allowed_ai,
        browser_ai_matrix=matrix,
        allowed_desktop_apps=allowed_desktop_apps,
        signature=p.signature,
        lecturer_id=p.lecturer_id,
        created_at=p.created_at,
        updated_at=p.updated_at
    )


@router.get("", response_model=List[AccessPolicyResponse])
def list_policies(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "lecturer":
        raise HTTPException(status_code=403, detail="Only lecturers can view policy templates")

    policies = db.query(AccessPolicy).filter(AccessPolicy.lecturer_id == current_user.id).order_by(AccessPolicy.created_at.desc()).all()
    return [parse_policy_response(p) for p in policies]


@router.post("", response_model=AccessPolicyResponse, status_code=status.HTTP_201_CREATED)
def create_policy(
    policy_in: AccessPolicyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    if current_user.role != "lecturer":
        raise HTTPException(status_code=403, detail="Only lecturers can create access policies")

    new_policy = AccessPolicy(
        title=policy_in.title,
        description=policy_in.description,
        version=1,
        default_action="DENY",
        policy_mode=policy_in.policy_mode,
        browser_mode=policy_in.browser_mode,
        ai_mode=policy_in.ai_mode,
        web_access_scope=policy_in.web_access_scope,
        desktop_app_mode=policy_in.desktop_app_mode,
        allowed_browsers=json.dumps(policy_in.allowed_browsers),
        allowed_ai=json.dumps(policy_in.allowed_ai),
        browser_ai_matrix=json.dumps(policy_in.browser_ai_matrix),
        allowed_desktop_apps=json.dumps(policy_in.allowed_desktop_apps),
        lecturer_id=current_user.id
    )

    # Calculate initial signature
    sig_payload = {
        "title": new_policy.title,
        "default_action": "DENY",
        "policy_mode": new_policy.policy_mode,
        "browser_mode": new_policy.browser_mode,
        "ai_mode": new_policy.ai_mode,
        "web_access_scope": new_policy.web_access_scope,
        "allowed_browsers": policy_in.allowed_browsers,
        "allowed_ai": policy_in.allowed_ai,
        "browser_ai_matrix": policy_in.browser_ai_matrix,
    }
    new_policy.signature = generate_policy_signature(sig_payload)

    db.add(new_policy)
    db.commit()
    db.refresh(new_policy)

    return parse_policy_response(new_policy)


@router.get("/{policy_id}", response_model=AccessPolicyResponse)
def get_policy(
    policy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    policy = db.query(AccessPolicy).filter(AccessPolicy.id == policy_id).first()
    if not policy:
        raise HTTPException(status_code=404, detail="Access policy not found")
    return parse_policy_response(policy)


@router.put("/{policy_id}", response_model=AccessPolicyResponse)
def update_policy(
    policy_id: str,
    policy_in: AccessPolicyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    policy = db.query(AccessPolicy).filter(AccessPolicy.id == policy_id).first()
    if not policy:
        raise HTTPException(status_code=404, detail="Access policy not found")
    if policy.lecturer_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to edit this policy")

    policy.title = policy_in.title
    policy.description = policy_in.description
    policy.version += 1
    policy.policy_mode = policy_in.policy_mode
    policy.browser_mode = policy_in.browser_mode
    policy.ai_mode = policy_in.ai_mode
    policy.web_access_scope = policy_in.web_access_scope
    policy.desktop_app_mode = policy_in.desktop_app_mode
    policy.allowed_browsers = json.dumps(policy_in.allowed_browsers)
    policy.allowed_ai = json.dumps(policy_in.allowed_ai)
    policy.browser_ai_matrix = json.dumps(policy_in.browser_ai_matrix)
    policy.allowed_desktop_apps = json.dumps(policy_in.allowed_desktop_apps)

    sig_payload = {
        "title": policy.title,
        "version": policy.version,
        "default_action": "DENY",
        "policy_mode": policy.policy_mode,
        "browser_mode": policy.browser_mode,
        "ai_mode": policy.ai_mode,
        "web_access_scope": policy.web_access_scope,
        "allowed_browsers": policy_in.allowed_browsers,
        "allowed_ai": policy_in.allowed_ai,
        "browser_ai_matrix": policy_in.browser_ai_matrix,
    }
    policy.signature = generate_policy_signature(sig_payload)

    db.commit()
    db.refresh(policy)
    return parse_policy_response(policy)


@router.get("/{policy_id}/preview", response_model=PolicyPreviewResponse)
def preview_policy(
    policy_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    policy = db.query(AccessPolicy).filter(AccessPolicy.id == policy_id).first()
    if not policy:
        raise HTTPException(status_code=404, detail="Access policy not found")

    browsers = db.query(BrowserResource).all()
    ai_services = db.query(AIResource).all()

    return generate_policy_preview(policy, browsers, ai_services)


@router.post("/preview-draft", response_model=PolicyPreviewResponse)
def preview_draft_policy(
    policy_in: AccessPolicyCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    browsers = db.query(BrowserResource).all()
    ai_services = db.query(AIResource).all()

    temp_policy = AccessPolicy(
        id="draft",
        title=policy_in.title,
        description=policy_in.description,
        version=1,
        default_action="DENY",
        policy_mode=policy_in.policy_mode,
        browser_mode=policy_in.browser_mode,
        ai_mode=policy_in.ai_mode,
        web_access_scope=policy_in.web_access_scope,
        desktop_app_mode=policy_in.desktop_app_mode,
        allowed_browsers=json.dumps(policy_in.allowed_browsers),
        allowed_ai=json.dumps(policy_in.allowed_ai),
        browser_ai_matrix=json.dumps(policy_in.browser_ai_matrix),
        allowed_desktop_apps=json.dumps(policy_in.allowed_desktop_apps),
        lecturer_id=current_user.id
    )

    return generate_policy_preview(temp_policy, browsers, ai_services)


@router.get("/{policy_id}/signed", response_model=SignedPolicyPayload)
def get_signed_policy(
    policy_id: str,
    db: Session = Depends(get_db)
):
    policy = db.query(AccessPolicy).filter(AccessPolicy.id == policy_id).first()
    if not policy:
        raise HTTPException(status_code=404, detail="Access policy not found")

    browsers = db.query(BrowserResource).all()
    ai_services = db.query(AIResource).all()

    return create_signed_policy_payload(policy, browsers, ai_services)
