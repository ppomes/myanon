#
# Python helpers for phpbb-myanon.conf.
#
# Every kind of personal data goes through one function, keyed by an HMAC of
# the original value and the myanon secret, so the same person gets the same
# fake value in every table. Registered users become user<user_id> everywhere
# their name is copied (topics, forums, newest member). Bots and the
# anonymous user keep their name.
#
# Values arrive from myanon still SQL-escaped (without the surrounding
# quotes), so they are unescaped before processing and escaped again on the
# way out. Values that are not changed are returned exactly as received.
#

import hashlib
import hmac
import os
import re

import myanon_utils

FAKE_DOMAIN = 'example.com'
FAKE_IP = '192.0.2.1'            # TEST-NET-1 (RFC 5737), never routed
LOREM = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit.'
SUBJECT = 'Lorem ipsum'

# bcrypt hash of 'password' (understood by phpBB whatever the PHP build)
PASSWORD_HASH = '$2y$10$066meQBh4RMqk5k7Cm.g1e0a8.bjV51oEpkCa22mvqHRAcjX90LPa'

USER_IGNORE = '2'                # phpBB user_type of bots and the anonymous user
ANONYMOUS = '1'                  # phpBB user_id of the anonymous user

_EMAIL_RE = re.compile(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}')

_CONFIG_EMAIL = {'board_contact', 'board_email'}

# newest_user_id is dumped just before newest_username (primary key order)
_newest_user_id = ''


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


def _poster(user_id, real_name):
    """Name of a poster: user<id> for registered users, a fake name for guests."""
    if user_id and user_id != ANONYMOUS:
        return 'user' + user_id
    return _fake_name(real_name)


# ---------------------------------------------------------------------------
# Functions called from phpbb-myanon.conf
# ---------------------------------------------------------------------------

def email(value):
    return _esc(_fake_email(_unesc(value)))


def name(value):
    return _esc(_fake_name(_unesc(value)))


def ip(value):
    return FAKE_IP if _unesc(value).strip() else value


def lorem(value):
    return LOREM if _unesc(value).strip() else value


def subject(value):
    return SUBJECT if _unesc(value).strip() else value


def username(value):
    """phpbb_users.username / username_clean: user<user_id>, bots kept."""
    if _row('user_type') == USER_IGNORE:
        return value
    return 'user' + _row('user_id')


def poster_name(value, id_column):
    """Copies of a poster's name, e.g. topic_first_poster_name. The parameter
    names the column holding the poster's user_id in the same row."""
    return _esc(_poster(_row(id_column), _unesc(value)))


def post_username(value):
    """phpbb_posts.post_username: only set for guest posts."""
    return name(value)


def config_value(value):
    """phpbb_config.config_value"""
    global _newest_user_id
    key = _row('config_name')
    if key in _CONFIG_EMAIL:
        return email(value)
    if key == 'newest_user_id':
        _newest_user_id = _unesc(value)
        return value
    if key == 'newest_username':
        return _esc(_poster(_newest_user_id, _unesc(value)))
    real = _unesc(value)
    new = _scrub_text(real)
    return value if new == real else _esc(new)


def password(value):
    """Every account gets 'password'; bots and the anonymous user keep none."""
    return PASSWORD_HASH if _unesc(value) else value


def filename(value):
    """Attachment names shown to users, renamed with their extension kept."""
    real = _unesc(value)
    stem, ext = os.path.splitext(real)
    if not stem:
        return value
    return _esc(_letters('file:' + stem, 8) + ext)
