import json
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Any
from app.models import AccessPolicy, BrowserResource, AIResource
from app.schemas import SignedPolicyPayload, PolicyPreviewResponse, PreviewMatrixItem
from app.policy_core import (
    evaluate_request,
    generate_policy_signature,
    verify_policy_signature,
)


def create_signed_policy_payload(
    policy: AccessPolicy,
    browsers: List[BrowserResource],
    ai_services: List[AIResource],
    ttl_hours: int = 12
) -> SignedPolicyPayload:
    """
    Constructs a complete signed policy payload suitable for student client enforcement.
    """
    now = datetime.now(timezone.utc)
    expires_at = now + timedelta(hours=ttl_hours)

    allowed_browsers = json.loads(policy.allowed_browsers) if isinstance(policy.allowed_browsers, str) else policy.allowed_browsers
    allowed_ai = json.loads(policy.allowed_ai) if isinstance(policy.allowed_ai, str) else policy.allowed_ai
    matrix = json.loads(policy.browser_ai_matrix) if isinstance(policy.browser_ai_matrix, str) else policy.browser_ai_matrix
    allowed_desktop_apps = json.loads(policy.allowed_desktop_apps) if isinstance(policy.allowed_desktop_apps, str) else policy.allowed_desktop_apps

    reg_browsers = []
    for b in browsers:
        execs = json.loads(b.executables) if isinstance(b.executables, str) else b.executables
        reg_browsers.append({
            "id": b.id,
            "name": b.name,
            "executables": execs,
            "description": b.description,
            "is_custom": b.is_custom,
            "created_at": b.created_at.isoformat() if b.created_at else now.isoformat()
        })

    reg_ai = []
    for a in ai_services:
        doms = json.loads(a.domains) if isinstance(a.domains, str) else a.domains
        d_execs = json.loads(a.desktop_executables) if isinstance(a.desktop_executables, str) else a.desktop_executables
        reg_ai.append({
            "id": a.id,
            "name": a.name,
            "domains": doms,
            "desktop_executables": d_execs,
            "description": a.description,
            "is_custom": a.is_custom,
            "created_at": a.created_at.isoformat() if a.created_at else now.isoformat()
        })

    payload_dict = {
        "policy_id": policy.id,
        "version": policy.version,
        "issued_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
        "default_action": "DENY",
        "policy_mode": policy.policy_mode,
        "browser_mode": policy.browser_mode,
        "ai_mode": policy.ai_mode,
        "web_access_scope": policy.web_access_scope,
        "desktop_app_mode": policy.desktop_app_mode,
        "registered_browsers": reg_browsers,
        "registered_ai": reg_ai,
        "allowed_browsers": allowed_browsers,
        "allowed_ai": allowed_ai,
        "browser_ai_matrix": matrix,
        "allowed_desktop_apps": allowed_desktop_apps,
    }

    sig = generate_policy_signature(payload_dict)

    return SignedPolicyPayload(
        policy_id=policy.id,
        version=policy.version,
        issued_at=now.isoformat(),
        expires_at=expires_at.isoformat(),
        default_action="DENY",
        policy_mode=policy.policy_mode,
        browser_mode=policy.browser_mode,
        ai_mode=policy.ai_mode,
        web_access_scope=policy.web_access_scope,
        desktop_app_mode=policy.desktop_app_mode,
        registered_browsers=reg_browsers,
        registered_ai=reg_ai,
        allowed_browsers=allowed_browsers,
        allowed_ai=allowed_ai,
        browser_ai_matrix=matrix,
        allowed_desktop_apps=allowed_desktop_apps,
        signature=sig
    )


def generate_policy_preview(
    policy: AccessPolicy,
    browsers: List[BrowserResource],
    ai_services: List[AIResource]
) -> PolicyPreviewResponse:
    """
    Simulates all permutations of Browsers, AI Services, Browser-AI Pairs, and Desktop Apps
    to show the lecturer an explicit ALLOW/DENY matrix result before activation.
    """
    allowed_browsers = json.loads(policy.allowed_browsers) if isinstance(policy.allowed_browsers, str) else policy.allowed_browsers
    allowed_ai = json.loads(policy.allowed_ai) if isinstance(policy.allowed_ai, str) else policy.allowed_ai
    matrix = json.loads(policy.browser_ai_matrix) if isinstance(policy.browser_ai_matrix, str) else policy.browser_ai_matrix
    allowed_desktop_apps = json.loads(policy.allowed_desktop_apps) if isinstance(policy.allowed_desktop_apps, str) else policy.allowed_desktop_apps

    browser_summary = []
    for b in browsers:
        is_allowed = policy.browser_mode == "ALLOW_ANY" or (
            policy.browser_mode == "ALLOW_SELECTED" and b.id in allowed_browsers
        )
        browser_summary.append({
            "id": b.id,
            "name": b.name,
            "status": "ALLOW" if is_allowed else "DENY",
            "reason": "Explicitly selected in policy" if is_allowed else "Default Deny (Not selected)"
        })

    ai_summary = []
    for a in ai_services:
        is_allowed = policy.ai_mode == "ALLOW_ANY" or (
            policy.ai_mode == "ALLOW_SELECTED" and a.id in allowed_ai
        )
        ai_summary.append({
            "id": a.id,
            "name": a.name,
            "status": "ALLOW" if is_allowed else "DENY",
            "reason": "Explicitly selected in policy" if is_allowed else "Default Deny (Not selected)"
        })

    matrix_rules = []
    for b in browsers:
        b_is_allowed = policy.browser_mode == "ALLOW_ANY" or (
            policy.browser_mode == "ALLOW_SELECTED" and b.id in allowed_browsers
        )
        b_matrix_ai = matrix.get(b.id, [])

        if not b_matrix_ai:
            matrix_rules.append(PreviewMatrixItem(
                browser_name=b.name,
                browser_status="ALLOW" if b_is_allowed else "DENY",
                ai_name="NONE (Standard Web Only)",
                ai_status="DENY_ALL_AI",
                pair_permission="ALLOW_BROWSER_NO_AI" if b_is_allowed else "DENY",
                reason="Browser allowed but all AI services restricted" if b_is_allowed else "Browser denied"
            ))

        for a in ai_services:
            a_is_allowed = policy.ai_mode == "ALLOW_ANY" or (
                policy.ai_mode == "ALLOW_SELECTED" and a.id in allowed_ai
            )
            matrix_allows = (
                policy.ai_mode == "ALLOW_ANY"
                or a.id in b_matrix_ai
                or a.id in matrix.get("*", [])
            )
            pair_allowed = b_is_allowed and a_is_allowed and matrix_allows

            if pair_allowed:
                reason = f"Explicitly authorized pair ({b.name} + {a.name})"
                perm = "ALLOW"
            elif not b_is_allowed:
                reason = f"Browser '{b.name}' is denied"
                perm = "DENY"
            elif not a_is_allowed:
                reason = f"AI service '{a.name}' is globally denied"
                perm = "DENY"
            else:
                reason = f"AI '{a.name}' not associated with browser '{b.name}' in matrix"
                perm = "DENY"

            matrix_rules.append(PreviewMatrixItem(
                browser_name=b.name,
                browser_status="ALLOW" if b_is_allowed else "DENY",
                ai_name=a.name,
                ai_status="ALLOW" if a_is_allowed else "DENY",
                pair_permission=perm,
                reason=reason
            ))

    desktop_app_summary = []
    for a in ai_services:
        d_execs = json.loads(a.desktop_executables) if isinstance(a.desktop_executables, str) else a.desktop_executables
        for exe in d_execs:
            is_allowed = exe in allowed_desktop_apps
            desktop_app_summary.append({
                "app_name": f"{a.name} Desktop ({exe})",
                "status": "ALLOW" if is_allowed else "DENY",
                "reason": "Explicitly allowed desktop binary" if is_allowed else "Blocked desktop AI application"
            })

    return PolicyPreviewResponse(
        policy_title=policy.title,
        default_action="DENY",
        browser_summary=browser_summary,
        ai_summary=ai_summary,
        matrix_rules=matrix_rules,
        desktop_app_summary=desktop_app_summary
    )

