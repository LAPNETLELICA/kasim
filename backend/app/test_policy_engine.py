import unittest
from app.policy_engine import evaluate_request, generate_policy_signature, verify_policy_signature

class TestPolicyEngine(unittest.TestCase):
    def setUp(self):
        self.sample_policy = {
            "policy_id": "test_pol_1",
            "version": 1,
            "default_action": "DENY",
            "browser_mode": "ALLOW_SELECTED",
            "ai_mode": "ALLOW_SELECTED",
            "desktop_app_mode": "BLOCK_ALL_UNAUTHORIZED",
            "registered_browsers": [
                {"id": "brw_chrome", "name": "Chrome", "executables": ["chrome.exe", "google-chrome"]},
                {"id": "brw_firefox", "name": "Firefox", "executables": ["firefox.exe", "firefox"]}
            ],
            "registered_ai": [
                {"id": "ai_claude", "name": "Claude", "domains": ["claude.ai"], "desktop_executables": ["Claude.exe"]},
                {"id": "ai_chatgpt", "name": "ChatGPT", "domains": ["chatgpt.com"], "desktop_executables": ["ChatGPT.exe"]}
            ],
            "allowed_browsers": ["brw_chrome"],
            "allowed_ai": ["ai_claude", "ai_chatgpt"],
            "browser_ai_matrix": {
                "brw_chrome": ["ai_claude"] # Chrome -> Claude ALLOWED, Chrome -> ChatGPT DENIED
            },
            "allowed_desktop_apps": []
        }

    def test_browser_allowed(self):
        perm, reason = evaluate_request(self.sample_policy, browser_exe="chrome.exe")
        self.assertEqual(perm, "ALLOW")

    def test_browser_denied(self):
        perm, reason = evaluate_request(self.sample_policy, browser_exe="firefox.exe")
        self.assertEqual(perm, "DENY")

    def test_unknown_browser_denied(self):
        perm, reason = evaluate_request(self.sample_policy, browser_exe="opera.exe")
        self.assertEqual(perm, "DENY")

    def test_browser_ai_pair_allowed(self):
        # Chrome + Claude -> ALLOW
        perm, reason = evaluate_request(self.sample_policy, browser_exe="chrome.exe", target_domain="claude.ai")
        self.assertEqual(perm, "ALLOW")

    def test_browser_ai_pair_denied_matrix(self):
        # Chrome + ChatGPT -> DENY (ChatGPT not in Chrome matrix)
        perm, reason = evaluate_request(self.sample_policy, browser_exe="chrome.exe", target_domain="chatgpt.com")
        self.assertEqual(perm, "DENY")

    def test_unregistered_ai_allowed_for_normal_web(self):
        # Chrome + wikipedia.org -> ALLOW (normal website)
        perm, reason = evaluate_request(self.sample_policy, browser_exe="chrome.exe", target_domain="wikipedia.org")
        self.assertEqual(perm, "ALLOW")

    def test_desktop_app_denied(self):
        # Claude.exe desktop app -> DENY (not in allowed_desktop_apps)
        perm, reason = evaluate_request(self.sample_policy, desktop_exe="Claude.exe")
        self.assertEqual(perm, "DENY")

    def test_hmac_signing(self):
        payload = {"policy_id": "123", "version": 1}
        sig = generate_policy_signature(payload)
        self.assertTrue(verify_policy_signature(payload, sig))
        self.assertFalse(verify_policy_signature(payload, "invalid_signature"))

if __name__ == "__main__":
    unittest.main()
