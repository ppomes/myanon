import myanon_utils
import hashlib, hmac

def anonymize_email(email):
    if email.endswith('@company.ext'):
        return email
    secret = myanon_utils.get_secret()
    h = hmac.new(secret.encode(), email.encode(), hashlib.sha256).hexdigest()
    return h[:len(email)]

def anonymize_name(name):
    row = myanon_utils.get_row()
    email = row.get('`email`', '')
    if email.endswith('@company.ext'):
        return name
    secret = myanon_utils.get_secret()
    h = hmac.new(secret.encode(), name.encode(), hashlib.sha256).hexdigest()
    return h[:len(name)]
