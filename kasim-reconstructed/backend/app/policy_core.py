"""Dependency-free policy signing and evaluation primitives.

Keeping these rules free of FastAPI and database imports lets the desktop
agent and CI test the five modes without booting the service.
"""

import hashlib
import hmac
import json
import os
from typing import Optional, Tuple


SECRET_KEY = os.getenv("POLICY_SIGNING_KEY", "kasim-local-development-signing-key")


def generate_policy_signature(policy_data: dict) -> str:
    canonical_json = json.dumps(
        policy_data,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    )
    return hmac.new(
        SECRET_KEY.encode("utf-8"),
        canonical_json.encode("utf-8"),
        hashlib.sha256,
    ).hexdigest()


def verify_policy_signature(policy_data: dict, signature: str) -> bool:
    return hmac.compare_digest(generate_policy_signature(policy_data), signature)


def evaluate_request(
    policy_payload: dict,
    browser_exe: Optional[str] = None,
    target_domain: Optional[str] = None,
    desktop_exe: Optional[str] = None,
) -> Tuple[str, str]:
    default_action = policy_payload.get("default_action", "DENY")

    if desktop_exe:
        for ai in policy_payload.get("registered_ai", []):
            if desktop_exe in ai.get("desktop_executables", []):
                if desktop_exe in policy_payload.get("allowed_desktop_apps", []):
                    return "ALLOW", f"Explicitly authorized desktop app '{desktop_exe}'"
                return "DENY", f"Unauthorized desktop AI application '{desktop_exe}' (Default Deny)"
        if policy_payload.get("desktop_app_mode") == "BLOCK_ALL_UNAUTHORIZED":
            return "DENY", f"Unrecognized process '{desktop_exe}' (Default Deny)"

    browser_mode = policy_payload.get("browser_mode", "ALLOW_SELECTED")
    ai_mode = policy_payload.get("ai_mode", "BLOCK_ALL")
    web_scope = policy_payload.get("web_access_scope", "ANY_SITE")
    matched_browser = None
    if browser_exe:
        for browser in policy_payload.get("registered_browsers", []):
            if browser_exe in browser.get("executables", []):
                matched_browser = browser
                break
        if not matched_browser and browser_mode == "ALLOW_ANY":
            matched_browser = {"id": "*", "name": browser_exe}
        elif not matched_browser:
            return "DENY", f"Unregistered browser executable '{browser_exe}' (Default Deny)"
        if browser_mode != "ALLOW_ANY" and matched_browser["id"] not in policy_payload.get("allowed_browsers", []):
            return "DENY", f"Browser '{matched_browser['name']}' is not authorized in current policy"

    if target_domain and matched_browser:
        matched_ai = None
        for ai in policy_payload.get("registered_ai", []):
            if any(
                target_domain == domain or target_domain.endswith("." + domain)
                for domain in ai.get("domains", [])
            ):
                matched_ai = ai
                break

        if matched_ai:
            if ai_mode == "BLOCK_ALL":
                return "DENY", f"AI service '{matched_ai['name']}' ({target_domain}) is blocked for this exam"
            if ai_mode != "ALLOW_ANY" and matched_ai["id"] not in policy_payload.get("allowed_ai", []):
                return "DENY", f"AI service '{matched_ai['name']}' ({target_domain}) is not authorized in current policy"
            matrix = policy_payload.get("browser_ai_matrix", {})
            selected = matrix.get(matched_browser["id"], [])
            wildcard = matrix.get("*", [])
            if ai_mode != "ALLOW_ANY" and matched_ai["id"] not in selected and matched_ai["id"] not in wildcard:
                return "DENY", f"AI service '{matched_ai['name']}' is not authorized for browser '{matched_browser['name']}' in matrix"
            return "ALLOW", f"Authorized pair: '{matched_browser['name']}' + '{matched_ai['name']}'"

        if web_scope == "AI_ONLY":
            return "DENY", "Standard web traffic is disabled; only the selected AI service is allowed"
        return "ALLOW", f"Standard web traffic allowed on '{target_domain}' via '{matched_browser['name']}'"

    if matched_browser and (
        browser_mode == "ALLOW_ANY"
        or matched_browser["id"] in policy_payload.get("allowed_browsers", [])
    ):
        return "ALLOW", f"Browser '{matched_browser['name']}' process authorized"
    return default_action, "Default-Deny Fallback"
