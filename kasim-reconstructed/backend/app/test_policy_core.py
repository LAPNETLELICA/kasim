import unittest

from app.policy_core import (
    evaluate_request,
    generate_policy_signature,
    verify_policy_signature,
)


class PolicyCoreTests(unittest.TestCase):
    def setUp(self):
        self.base = {
            "default_action": "DENY",
            "desktop_app_mode": "BLOCK_ALL_UNAUTHORIZED",
            "registered_browsers": [
                {"id": "chrome", "name": "Chrome", "executables": ["chrome.exe"]},
                {"id": "firefox", "name": "Firefox", "executables": ["firefox.exe"]},
            ],
            "registered_ai": [
                {"id": "tutor", "name": "Tutor AI", "domains": ["tutor.example.edu"], "desktop_executables": []},
                {"id": "other", "name": "Other AI", "domains": ["other.ai"], "desktop_executables": []},
            ],
            "allowed_desktop_apps": [],
        }

    def test_specific_browser(self):
        policy = {
            **self.base,
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_ANY",
            "web_access_scope": "ANY_SITE",
            "allowed_browsers": ["chrome"],
            "allowed_ai": [],
            "browser_ai_matrix": {"chrome": ["*"]},
        }
        self.assertEqual(evaluate_request(policy, "chrome.exe", "other.ai")[0], "ALLOW")
        self.assertEqual(evaluate_request(policy, "firefox.exe", "other.ai")[0], "DENY")

    def test_specific_ai_only(self):
        policy = {
            **self.base,
            "browser_mode": "ALLOW_ANY",
            "ai_mode": "ALLOW_SELECTED",
            "web_access_scope": "AI_ONLY",
            "allowed_browsers": [],
            "allowed_ai": ["tutor"],
            "browser_ai_matrix": {"*": ["tutor"]},
        }
        self.assertEqual(evaluate_request(policy, "new.exe", "tutor.example.edu")[0], "ALLOW")
        self.assertEqual(evaluate_request(policy, "new.exe", "wikipedia.org")[0], "DENY")
        self.assertEqual(evaluate_request(policy, "new.exe", "other.ai")[0], "DENY")

    def test_specific_browser_without_ai(self):
        policy = {
            **self.base,
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "BLOCK_ALL",
            "web_access_scope": "ANY_SITE",
            "allowed_browsers": ["chrome"],
            "allowed_ai": [],
            "browser_ai_matrix": {"chrome": []},
        }
        self.assertEqual(evaluate_request(policy, "chrome.exe", "wikipedia.org")[0], "ALLOW")
        self.assertEqual(evaluate_request(policy, "chrome.exe", "tutor.example.edu")[0], "DENY")

    def test_any_browser_without_ai(self):
        policy = {
            **self.base,
            "browser_mode": "ALLOW_ANY",
            "ai_mode": "BLOCK_ALL",
            "web_access_scope": "ANY_SITE",
            "allowed_browsers": [],
            "allowed_ai": [],
            "browser_ai_matrix": {},
        }
        self.assertEqual(evaluate_request(policy, "brand-new.exe", "wikipedia.org")[0], "ALLOW")
        self.assertEqual(evaluate_request(policy, "brand-new.exe", "tutor.example.edu")[0], "DENY")

    def test_specific_browser_and_ai(self):
        policy = {
            **self.base,
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_SELECTED",
            "web_access_scope": "ANY_SITE",
            "allowed_browsers": ["chrome"],
            "allowed_ai": ["tutor"],
            "browser_ai_matrix": {"chrome": ["tutor"]},
        }
        self.assertEqual(evaluate_request(policy, "chrome.exe", "tutor.example.edu")[0], "ALLOW")
        self.assertEqual(evaluate_request(policy, "chrome.exe", "other.ai")[0], "DENY")

    def test_signature_is_deterministic_and_tamper_evident(self):
        payload = {"z": [3, {"b": 2, "a": "é"}], "a": 1}
        signature = generate_policy_signature(payload)
        self.assertTrue(verify_policy_signature(payload, signature))
        self.assertFalse(verify_policy_signature({**payload, "a": 2}, signature))


if __name__ == "__main__":
    unittest.main()
