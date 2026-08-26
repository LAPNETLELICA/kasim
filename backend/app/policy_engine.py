import hmac
import hashlib
import json
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Any, Tuple
from app.models import AccessPolicy, BrowserResource, AIResource
from app.schemas import SignedPolicyPayload, PolicyPreviewResponse, PreviewMatrixItem


SECRET_KEY = "kasim_policy_signing_secret_key_production_grade"


def generate_policy_signature(policy_data: dict) -> str:
    """
    Computes a deterministic HMAC-SHA256 signature for a policy payload.
    """
    canonical_json = json.dumps(policy_data, sort_keys=True)
    return hmac.new(
        SECRET_KEY.encode('utf-8'),
        canonical_json.encode('utf-8'),
        hashlib.sha256
    ).hexdigest()


def verify_policy_signature(policy_data: dict, signature: str) -> bool:
    """
    Verifies that the HMAC signature matches the policy content.
    """
    expected_sig = generate_policy_signature(policy_data)
    return hmac.compare_digest(expected_sig, signature)


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
            "created_at": b.created_at
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
            "created_at": a.created_at
        })

    payload_dict = {
        "policy_id": policy.id,
        "version": policy.version,
        "issued_at": now.isoformat(),
        "expires_at": expires_at.isoformat(),
        "default_action": "DENY",
        "browser_mode": policy.browser_mode,
        "ai_mode": policy.ai_mode,
        "desktop_app_mode": policy.desktop_app_mode,
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
        browser_mode=policy.browser_mode,
        ai_mode=policy.ai_mode,
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
        is_allowed = (b.id in allowed_browsers) if policy.browser_mode == "ALLOW_SELECTED" else False
        browser_summary.append({
            "id": b.id,
            "name": b.name,
            "status": "ALLOW" if is_allowed else "DENY",
            "reason": "Explicitly selected in policy" if is_allowed else "Default Deny (Not selected)"
        })

    ai_summary = []
    for a in ai_services:
        is_allowed = (a.id in allowed_ai) if policy.ai_mode == "ALLOW_SELECTED" else False
        ai_summary.append({
            "id": a.id,
            "name": a.name,
            "status": "ALLOW" if is_allowed else "DENY",
            "reason": "Explicitly selected in policy" if is_allowed else "Default Deny (Not selected)"
        })

    matrix_rules = []
    for b in browsers:
        b_is_allowed = (b.id in allowed_browsers) if policy.browser_mode == "ALLOW_SELECTED" else False
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
            a_is_allowed = (a.id in allowed_ai) if policy.ai_mode == "ALLOW_SELECTED" else False
            pair_allowed = b_is_allowed and a_is_allowed and (a.id in b_matrix_ai)

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


def evaluate_request(
    policy_payload: dict,
    browser_exe: str = None,
    target_domain: str = None,
    desktop_exe: str = None
) -> Tuple[str, str]:
    """
    Core local evaluation function implementing the Default-Deny logic.
    Returns (PERMISSION: "ALLOW" | "DENY", REASON: str).
    """
    default_action = policy_payload.get("default_action", "DENY")

    # 1. Desktop AI Application Evaluation
    if desktop_exe:
        for ai in policy_payload.get("registered_ai", []):
            if desktop_exe in ai.get("desktop_executables", []):
                if desktop_exe in policy_payload.get("allowed_desktop_apps", []):
                    return ("ALLOW", f"Explicitly authorized desktop app '{desktop_exe}'")
                return ("DENY", f"Unauthorized desktop AI application '{desktop_exe}' (Default Deny)")
        if policy_payload.get("desktop_app_mode") == "BLOCK_ALL_UNAUTHORIZED":
            return ("DENY", f"Unrecognized process '{desktop_exe}' (Default Deny)")

    # 2. Browser Identification & Authorization
    matched_browser = None
    if browser_exe:
        for b in policy_payload.get("registered_browsers", []):
            if browser_exe in b.get("executables", []):
                matched_browser = b
                break

        if not matched_browser:
            return ("DENY", f"Unregistered browser executable '{browser_exe}' (Default Deny)")

        if matched_browser["id"] not in policy_payload.get("allowed_browsers", []):
            return ("DENY", f"Browser '{matched_browser['name']}' is not authorized in current policy")

    # 3. Domain & AI Matrix Evaluation
    if target_domain and matched_browser:
        matched_ai = None
        for ai in policy_payload.get("registered_ai", []):
            for dom in ai.get("domains", []):
                if target_domain == dom or target_domain.endswith("." + dom):
                    matched_ai = ai
                    break
            if matched_ai:
                break

        if matched_ai:
            if matched_ai["id"] not in policy_payload.get("allowed_ai", []):
                return ("DENY", f"AI service '{matched_ai['name']}' ({target_domain}) is not authorized in current policy")

            allowed_matrix_ai = policy_payload.get("browser_ai_matrix", {}).get(matched_browser["id"], [])
            if matched_ai["id"] not in allowed_matrix_ai:
                return ("DENY", f"AI service '{matched_ai['name']}' is not authorized for browser '{matched_browser['name']}' in matrix")

            return ("ALLOW", f"Authorized pair: '{matched_browser['name']}' + '{matched_ai['name']}'")

        return ("ALLOW", f"Standard web traffic allowed on '{target_domain}' via '{matched_browser['name']}'")

    if matched_browser and matched_browser["id"] in policy_payload.get("allowed_browsers", []):
        return ("ALLOW", f"Browser '{matched_browser['name']}' process authorized")

    return (default_action, "Default-Deny Fallback")
