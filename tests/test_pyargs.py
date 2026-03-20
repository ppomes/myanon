import myanon_utils
import hashlib, hmac

def fake_text(value, params=None):
    parts = (params or '').split(',')
    max_length = int(parts[0]) if parts and parts[0] else 200
    fixed = 'fixed' in parts
    if fixed:
        return 'x' * min(len(value), max_length)
    secret = myanon_utils.get_secret()
    return hmac.new(secret.encode(), value.encode(), hashlib.sha256).hexdigest()[:max_length]
