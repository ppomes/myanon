#
# Python helpers for wordpress-myanon.conf (WordPress + WooCommerce).
#
# Every kind of personal data goes through one function, keyed by an HMAC of
# the original value and the myanon secret. The same person therefore gets
# the same fake value in every table: an e-mail address is replaced by the
# same fake address in wp_users, wp_usermeta, orders, addresses and so on.
#
# Values arrive from myanon still SQL-escaped (without the surrounding
# quotes), so they are unescaped before processing and escaped again on the
# way out. Values that are not changed are returned exactly as received.
#

import hashlib
import hmac
import re

import myanon_utils

FAKE_DOMAIN = 'example.com'
FAKE_IP = '192.0.2.1'            # TEST-NET-1 (RFC 5737), never routed
FAKE_STREET = 'Example Street'
FAKE_CITY = 'Springfield'
FAKE_COMPANY = 'Example Ltd'
EMPTY_ARRAY = 'a:0:{}'           # PHP serialize(array())

# Keys of wp_usermeta / wp_postmeta / wp_wc_orders_meta. Order data stored in
# post meta uses the same names with a leading underscore.
_NAME = {'first_name', 'last_name', 'billing_first_name', 'billing_last_name',
         'shipping_first_name', 'shipping_last_name'}
_EMAIL = {'billing_email'}
_DIGITS = {'billing_phone', 'shipping_phone'}
_POSTCODE = {'billing_postcode', 'shipping_postcode'}
_STREET = {'billing_address_1', 'shipping_address_1'}
_CITY = {'billing_city', 'shipping_city'}
_COMPANY = {'billing_company', 'shipping_company'}
_BLANK = {'description', 'billing_address_2', 'shipping_address_2',
          'billing_address_index', 'shipping_address_index',
          'customer_user_agent', 'transaction_id'}
_IP = {'customer_ip_address'}
_EMPTY_ARRAY = {'session_tokens', 'community-events-location'}

# wp_options
_OPTION_EMAIL = {'admin_email', 'new_admin_email', 'mailserver_login',
                 'woocommerce_email_from_address', 'woocommerce_stock_email_recipient',
                 'woocommerce_pos_store_email'}
_OPTION_BLANK = {'mailserver_pass'}

# Comments written by the system rather than by a person
_SYSTEM_COMMENT_TYPES = {'order_note', 'webhook_delivery', 'action_log'}
_ORDER_POST_TYPES = {'shop_order', 'shop_order_placeholder', 'shop_order_refund'}

_EMAIL_RE = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')
# s:<len>:"<string>";   or   C:<len>:"<class>":<len>:{<payload>}
_SERIALIZED_RE = re.compile(rb's:(\d+):"|C:(\d+):"([^"]*)":(\d+):\{')
_SERIALIZED_PREFIXES = ('a:', 's:', 'O:', 'C:')


# ---------------------------------------------------------------------------
# Building blocks
# ---------------------------------------------------------------------------

def _digest(value):
    secret = myanon_utils.get_secret().encode('utf-8', 'surrogateescape')
    return hmac.new(secret, value.encode('utf-8', 'surrogateescape'), hashlib.sha256).digest()


def _letters(value, length):
    d = _digest(value)
    return ''.join(chr(ord('a') + d[i % len(d)] % 26) for i in range(length))


def _unesc(value):
    return myanon_utils.unescape_sql_string(value)


def _esc(value):
    return myanon_utils.escape_sql_string(value)


def _row(column):
    """Unescaped value of another column of the current row ('' if NULL)."""
    value = myanon_utils.get_row().get('`%s`' % column, '')
    return '' if value == 'NULL' else _unesc(value)


def _fake_email(real):
    real = real.strip()
    if not real:
        return real
    return '%s@%s' % (_letters(real.lower(), 10), FAKE_DOMAIN)


def _fake_name(real):
    real = real.strip()
    if not real:
        return real
    return _letters(real, 7).capitalize()


def _fake_digits(real):
    """Replace every digit, keep spaces, dashes, '+' and so on."""
    d = _digest(real)
    out, i = [], 0
    for ch in real:
        if ch.isdigit():
            out.append(str(d[i % len(d)] % 10))
            i += 1
        else:
            out.append(ch)
    return ''.join(out)


def _fake_postcode(real):
    """Replace digits and letters (UK, Canadian, Dutch postcodes...), keep case and separators."""
    d = _digest(real)
    out = []
    for i, ch in enumerate(real):
        b = d[i % len(d)]
        if ch.isdigit():
            out.append(str(b % 10))
        elif 'a' <= ch.lower() <= 'z':
            c = chr(ord('a') + b % 26)
            out.append(c.upper() if ch.isupper() else c)
        else:
            out.append(ch)
    return ''.join(out)


def _fake_street(real):
    if not real.strip():
        return real
    return '%d %s' % (_digest(real)[0] % 199 + 1, FAKE_STREET)


def _scrub_text(text):
    return _EMAIL_RE.sub(lambda m: _fake_email(m.group(0)), text)


def _scrub_serialized(data):
    """Replace e-mails inside PHP serialized data, fixing the declared byte lengths."""
    out = bytearray()
    pos = 0
    for m in _SERIALIZED_RE.finditer(data):
        if m.start() < pos:
            continue
        start = m.end()
        if m.group(1) is not None:                      # s:<len>:"..."
            end = start + int(m.group(1))
            if data[end:end + 2] != b'";':
                continue
            inner = data[start:end]
            new = _scrub_value_bytes(inner)
            out += data[pos:m.start()] + b's:%d:"' % len(new) + new
        else:                                           # C:<len>:"<class>":<len>:{...}
            if int(m.group(2)) != len(m.group(3)):
                continue
            end = start + int(m.group(4))
            if data[end:end + 1] != b'}':
                continue
            inner = data[start:end]
            new = _scrub_value_bytes(inner)
            out += data[pos:m.start()] + b'C:%d:"%s":%d:{' % (len(m.group(3)), m.group(3), len(new)) + new
        pos = end
    out += data[pos:]
    return bytes(out)


def _scrub_value_bytes(raw):
    """Scrub a string that may itself contain serialized data."""
    if '@' not in raw.decode('utf-8', 'surrogateescape'):
        return raw
    if raw.decode('utf-8', 'surrogateescape')[:2] in _SERIALIZED_PREFIXES or _SERIALIZED_RE.search(raw):
        return _scrub_serialized(raw)
    return _scrub_text(raw.decode('utf-8', 'surrogateescape')).encode('utf-8', 'surrogateescape')


def _scrub_any(value):
    """Safety net for values no rule targets: replace any e-mail they contain."""
    if '@' not in value:
        return value
    real = _unesc(value)
    if real[:2] in _SERIALIZED_PREFIXES:
        raw = real.encode('utf-8', 'surrogateescape')
        new = _scrub_serialized(raw).decode('utf-8', 'surrogateescape')
    else:
        new = _scrub_text(real)
    return value if new == real else _esc(new)


def _by_key(key, value):
    """Apply the meta key rules. Returns None when no rule matches."""
    k = key[1:] if key.startswith('_') else key
    real = _unesc(value)
    if k in _NAME:
        return _esc(_fake_name(real))
    if k in _EMAIL:
        return _esc(_fake_email(real))
    if k in _DIGITS:
        return _esc(_fake_digits(real))
    if k in _POSTCODE:
        return _esc(_fake_postcode(real))
    if k in _STREET:
        return _esc(_fake_street(real))
    if k in _CITY:
        return FAKE_CITY if real else value
    if k in _COMPANY:
        return FAKE_COMPANY if real else value
    if k in _BLANK:
        return ''
    if k in _IP:
        return FAKE_IP if real else value
    if k in _EMPTY_ARRAY:
        return EMPTY_ARRAY
    return None


# ---------------------------------------------------------------------------
# Functions called from wordpress-myanon.conf
# ---------------------------------------------------------------------------

def email(value):
    return _esc(_fake_email(_unesc(value)))


def name(value):
    return _esc(_fake_name(_unesc(value)))


def digits(value):
    return _esc(_fake_digits(_unesc(value)))


def postcode(value):
    return _esc(_fake_postcode(_unesc(value)))


def street(value):
    return _esc(_fake_street(_unesc(value)))


def city(value):
    return FAKE_CITY if _unesc(value).strip() else value


def company(value):
    return FAKE_COMPANY if _unesc(value).strip() else value


def ip(value):
    return FAKE_IP if _unesc(value).strip() else value


def user_login(value):
    """wp_users.user_login / user_nicename: 'user<ID>', unique like the ID."""
    return 'user' + _row('ID')


def display_name(value):
    return 'User ' + _row('ID')


def lookup_username(value):
    """wp_wc_customer_lookup.username, consistent with wp_users.user_login."""
    user_id = _row('user_id')
    return 'user' + user_id if user_id and user_id != '0' else ''


def scrub(value):
    """Replace any e-mail in a value, including inside serialized data."""
    return _scrub_any(value)


def meta(value):
    """meta_value of wp_usermeta, wp_postmeta, wp_commentmeta, wp_wc_orders_meta."""
    key = _row('meta_key')
    if key == 'nickname':
        return 'user' + _row('user_id')
    new = _by_key(key, value)
    return _scrub_any(value) if new is None else new


def option(value):
    """wp_options.option_value"""
    key = _row('option_name')
    if key in _OPTION_EMAIL:
        return email(value)
    if key in _OPTION_BLANK:
        return ''
    return _scrub_any(value)


def comment_author(value):
    if _row('user_id') not in ('', '0'):
        return 'User ' + _row('user_id')
    if _row('comment_type') in _SYSTEM_COMMENT_TYPES:
        return value
    return name(value)


def comment_content(value):
    """Free text written by people is replaced; system notes are kept, minus e-mails."""
    if _row('comment_type') in _SYSTEM_COMMENT_TYPES:
        return _scrub_any(value)
    return 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'


def post_excerpt(value):
    """Orders stored as posts keep the customer note in post_excerpt."""
    if _row('post_type') in _ORDER_POST_TYPES:
        return ''
    return value
