#
# Python helpers for drupal-myanon.conf.
#
# Every kind of personal data goes through one function, keyed by an HMAC of
# the original value and the myanon secret, so the same person gets the same
# fake value in every table.
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
LOREM = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'

# \w matches Unicode letters too: josé@exemple.fr, 用户@例子.中国... but not
# combining accents, as in a decomposed 'jose\u0301@exemple.fr': add them.
_MARKS = '\u0300-\u036f\u1ab0-\u1aff\u1dc0-\u1dff\u20d0-\u20ff\ufe20-\ufe2f'
_EMAIL_RE = re.compile(r'[\w%s.%%+-]+@[\w%s-]+(?:\.[\w%s-]+)+' % ((_MARKS,) * 3))
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


def _scrub_text(text):
    return _EMAIL_RE.sub(lambda m: _fake_email(m.group(0)), text)


def _scrub_gap(data):
    """Text between serialized strings. In real serialized data it only holds
    structure (a:2:{, i:1;, }...), but a value that merely looks serialized
    can hold free text, so e-mails are replaced here too."""
    if b'@' not in data:
        return data
    return _scrub_text(data.decode('utf-8', 'surrogateescape')).encode('utf-8', 'surrogateescape')


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
            out += _scrub_gap(data[pos:m.start()]) + b's:%d:"' % len(new) + new
        else:                                           # C:<len>:"<class>":<len>:{...}
            if int(m.group(2)) != len(m.group(3)):
                continue
            end = start + int(m.group(4))
            if data[end:end + 1] != b'}':
                continue
            inner = data[start:end]
            new = _scrub_value_bytes(inner)
            out += _scrub_gap(data[pos:m.start()]) + b'C:%d:"%s":%d:{' % (len(m.group(3)), m.group(3), len(new)) + new
        pos = end
    out += _scrub_gap(data[pos:])
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


# ---------------------------------------------------------------------------
# Functions called from drupal-myanon.conf
# ---------------------------------------------------------------------------

def email(value):
    return _esc(_fake_email(_unesc(value)))


def name(value):
    return _esc(_fake_name(_unesc(value)))


def ip(value):
    return FAKE_IP if _unesc(value).strip() else value


def lorem(value):
    return LOREM if _unesc(value).strip() else value


def user_name(value):
    """users_field_data.name: 'user<uid>'. The anonymous user (uid 0) keeps its empty name."""
    real = _unesc(value)
    if not real:
        return value
    return 'user' + _row('uid')


def config_data(value):
    """config.data: serialized configuration, e-mails replaced (site mail,
    update notification e-mails...)."""
    return _scrub_any(value)
