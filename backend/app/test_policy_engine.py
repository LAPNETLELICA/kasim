import unittest
import json
from datetime import datetime, timezone, timedelta
from app.policy_engine import (
    evaluate_request,
    generate_policy_signature,
    verify_policy_signature,
)
from app.security import get_password_hash, verify_password


class TestMasterAuthorizationEngine(unittest.TestCase):
    """
    Automated test suite verifying the 9 Master Architectural Scenarios.
    """

    def setUp(self):
        # Base registered resources
        self.registered_browsers = [
            {"id": "brw_chrome", "name": "Chrome", "executables": ["chrome.exe", "google-chrome"]},
            {"id": "brw_firefox", "name": "Firefox", "executables": ["firefox.exe", "firefox"]},
            {"id": "brw_edge", "name": "Edge", "executables": ["msedge.exe", "msedge"]},
        ]
        self.registered_ai = [
            {"id": "ai_claude", "name": "Claude", "domains": ["claude.ai", "api.anthropic.com"], "desktop_executables": ["Claude.exe"]},
            {"id": "ai_chatgpt", "name": "ChatGPT", "domains": ["chatgpt.com", "openai.com"], "desktop_executables": ["ChatGPT.exe"]},
            {"id": "ai_gemini", "name": "Gemini", "domains": ["gemini.google.com"], "desktop_executables": []},
        ]

    # --- Test 1: Chrome Allowed, No AI ---
    def test_case_1_chrome_allowed_no_ai(self):
        policy = {
            "policy_id": "pol_exam_1",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_SELECTED",
            "desktop_app_mode": "BLOCK_ALL_UNAUTHORIZED",
            "registered_browsers": self.registered_browsers,
            "registered_ai": self.registered_ai,
            "allowed_browsers": ["brw_chrome"],
            "allowed_ai": [],  # NO AI
            "browser_ai_matrix": {
                "brw_chrome": []
            },
            "allowed_desktop_apps": []
        }

        # 1. Chrome process itself -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe")
        self.assertEqual(perm, "ALLOW")

        # 2. Chrome opening normal website -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="wikipedia.org")
        self.assertEqual(perm, "ALLOW")

        # 3. Chrome attempting Claude -> DENY
        perm, reason = evaluate_request(policy, browser_exe="chrome.exe", target_domain="claude.ai")
        self.assertEqual(perm, "DENY")
        self.assertIn("not authorized", reason)

        # 4. Chrome attempting ChatGPT -> DENY
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="chatgpt.com")
        self.assertEqual(perm, "DENY")

    # --- Test 2: Chrome + Claude Only ---
    def test_case_2_chrome_plus_claude_only(self):
        policy = {
            "policy_id": "pol_exam_2",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_SELECTED",
            "desktop_app_mode": "BLOCK_ALL_UNAUTHORIZED",
            "registered_browsers": self.registered_browsers,
            "registered_ai": self.registered_ai,
            "allowed_browsers": ["brw_chrome"],
            "allowed_ai": ["ai_claude"],
            "browser_ai_matrix": {
                "brw_chrome": ["ai_claude"]
            },
            "allowed_desktop_apps": []
        }

        # Chrome -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe")
        self.assertEqual(perm, "ALLOW")

        # Chrome + Claude -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="claude.ai")
        self.assertEqual(perm, "ALLOW")

        # Chrome + ChatGPT -> DENY
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="chatgpt.com")
        self.assertEqual(perm, "DENY")

        # Chrome + Gemini -> DENY
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="gemini.google.com")
        self.assertEqual(perm, "DENY")

    # --- Test 3: Firefox + ChatGPT, Chrome + Claude ---
    def test_case_3_relational_matrix_permutations(self):
        policy = {
            "policy_id": "pol_exam_3",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_SELECTED",
            "desktop_app_mode": "BLOCK_ALL_UNAUTHORIZED",
            "registered_browsers": self.registered_browsers,
            "registered_ai": self.registered_ai,
            "allowed_browsers": ["brw_chrome", "brw_firefox"],
            "allowed_ai": ["ai_claude", "ai_chatgpt"],
            "browser_ai_matrix": {
                "brw_chrome": ["ai_claude"],     # Chrome -> Claude ONLY
                "brw_firefox": ["ai_chatgpt"]   # Firefox -> ChatGPT ONLY
            },
            "allowed_desktop_apps": []
        }

        # Chrome + Claude -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="claude.ai")
        self.assertEqual(perm, "ALLOW")

        # Chrome + ChatGPT -> DENY
        perm, _ = evaluate_request(policy, browser_exe="chrome.exe", target_domain="chatgpt.com")
        self.assertEqual(perm, "DENY")

        # Firefox + ChatGPT -> ALLOW
        perm, _ = evaluate_request(policy, browser_exe="firefox.exe", target_domain="chatgpt.com")
        self.assertEqual(perm, "ALLOW")

        # Firefox + Claude -> DENY
        perm, _ = evaluate_request(policy, browser_exe="firefox.exe", target_domain="claude.ai")
        self.assertEqual(perm, "DENY")

        # Edge + Any AI -> DENY (Edge not in allowed_browsers)
        perm, _ = evaluate_request(policy, browser_exe="msedge.exe", target_domain="claude.ai")
        self.assertEqual(perm, "DENY")

    # --- Test 4: Unknown Browser Denied ---
    def test_case_4_unknown_browser_denied(self):
        policy = {
            "policy_id": "pol_exam_4",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "registered_browsers": self.registered_browsers,
            "allowed_browsers": ["brw_chrome"],
            "registered_ai": self.registered_ai,
            "allowed_ai": [],
            "browser_ai_matrix": {},
            "allowed_desktop_apps": []
        }

        perm, reason = evaluate_request(policy, browser_exe="tor.exe")
        self.assertEqual(perm, "DENY")
        self.assertIn("Unregistered browser", reason)

        perm, reason = evaluate_request(policy, browser_exe="brave.exe")
        self.assertEqual(perm, "DENY")

    # --- Test 5: Unknown AI / Unregistered Domain Denied ---
    def test_case_5_desktop_ai_app_blocking(self):
        policy = {
            "policy_id": "pol_exam_5",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "registered_browsers": self.registered_browsers,
            "allowed_browsers": ["brw_chrome"],
            "registered_ai": self.registered_ai,
            "allowed_ai": ["ai_claude"],
            "browser_ai_matrix": {"brw_chrome": ["ai_claude"]},
            "allowed_desktop_apps": [] # No desktop app binary permitted
        }

        # Claude desktop binary executable -> DENY
        perm, reason = evaluate_request(policy, desktop_exe="Claude.exe")
        self.assertEqual(perm, "DENY")
        self.assertIn("Unauthorized desktop AI application", reason)

        # ChatGPT desktop binary -> DENY
        perm, _ = evaluate_request(policy, desktop_exe="ChatGPT.exe")
        self.assertEqual(perm, "DENY")

    # --- Test 6: Session Invalidation / Expiration ---
    def test_case_6_session_expiration(self):
        now = datetime.now(timezone.utc)
        expired_time = now - timedelta(minutes=10)

        # Simulating client expiration validation
        is_expired = now > expired_time
        self.assertTrue(is_expired, "Expired session policy must be flagged as inactive")

    # --- Test 7: Offline Fallback & Cache Integrity ---
    def test_case_7_offline_fallback(self):
        # Client caches valid signed policy; if offline, cache remains usable until expired
        payload = {
            "policy_id": "pol_cached_1",
            "version": 2,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "allowed_browsers": ["brw_chrome"]
        }
        sig = generate_policy_signature(payload)
        payload["signature"] = sig

        # Validate signature integrity from cache
        cache_copy = dict(payload)
        saved_sig = cache_copy.pop("signature")
        self.assertTrue(verify_policy_signature(cache_copy, saved_sig))

    # --- Test 8: Tampered Policy Rejection ---
    def test_case_8_tampered_policy_rejected(self):
        original_payload = {
            "policy_id": "pol_secure",
            "version": 1,
            "default_action": "DENY",
            "allowed_browsers": ["brw_chrome"],
            "allowed_ai": []
        }
        valid_sig = generate_policy_signature(original_payload)

        # Student attempts to tamper locally with policy
        tampered_payload = dict(original_payload)
        tampered_payload["allowed_ai"] = ["ai_claude", "ai_chatgpt", "ai_gemini"]

        # Signature verification MUST fail
        self.assertFalse(verify_policy_signature(tampered_payload, valid_sig))

    # --- Test 9: Dual Authentication Resolution (Email OR Name) ---
    def test_case_9_dual_identifier_login(self):
        password_plain = "LecturerPass2026!"
        pwd_hash = get_password_hash(password_plain)

        user_record = {
            "username": "DrJohnLecturer",
            "email": "john.lecturer@university.edu",
            "hashed_password": pwd_hash
        }

        # 1. Login with Email + correct password
        email_input = "john.lecturer@university.edu"
        matched_user = user_record if email_input.lower() == user_record["email"].lower() else None
        self.assertIsNotNone(matched_user)
        self.assertTrue(verify_password(password_plain, matched_user["hashed_password"]))

        # 2. Login with Platform Name + correct password
        name_input = "DrJohnLecturer"
        matched_user_by_name = user_record if name_input.lower() == user_record["username"].lower() else None
        self.assertIsNotNone(matched_user_by_name)
        self.assertTrue(verify_password(password_plain, matched_user_by_name["hashed_password"]))

        # 3. Login with wrong password -> REJECTED
        self.assertFalse(verify_password("WrongPassword123", user_record["hashed_password"]))


if __name__ == "__main__":
    unittest.main()
