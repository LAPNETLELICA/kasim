import json
import os
import hmac
import hashlib
from datetime import datetime, timezone

SECRET_KEY = "kasim_policy_signing_secret_key_production_grade"
CACHE_FILE = ".policy_cache"

def verify_policy_signature(data: dict, signature: str) -> bool:
    copy = dict(data)
    copy.pop("signature", None)
    canonical = json.dumps(copy, sort_keys=True)
    expected = hmac.new(SECRET_KEY.encode('utf-8'), canonical.encode('utf-8'), hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)

def load_cached_policy() -> dict:
    if not os.path.exists(CACHE_FILE):
        return {}
    try:
        with open(CACHE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            sig = data.get("signature")
            if sig and verify_policy_signature(data, sig):
                exp = data.get("expires_at")
                if exp:
                    exp_dt = datetime.fromisoformat(exp.replace("Z", "+00:00"))
                    if datetime.now(timezone.utc) < exp_dt:
                        return data
    except Exception:
        pass
    return {}
