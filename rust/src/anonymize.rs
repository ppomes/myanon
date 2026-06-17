use hmac::{Hmac, Mac};
use sha2::Sha256;

use crate::config::{AnonBase, AnonType};

type HmacSha256 = Hmac<Sha256>;

#[derive(Debug, Clone, PartialEq)]
pub enum QuoteMode {
    AsInput,
    ForceTrue,
    ForceFalse,
}

#[derive(Debug)]
pub struct AnonResult {
    pub data: Vec<u8>,
    pub quoting: QuoteMode,
}

pub struct AnonContext<'a> {
    pub tablekey: &'a mut String,
    pub rowindex: i32,
    pub bfirstinsert: bool,
    pub tablename: &'a str,
}

/// Escape single quotes and backslashes for MySQL output (doubling style).
pub fn mysql_escape(src: &str) -> Vec<u8> {
    let mut out = Vec::with_capacity(src.len());
    mysql_escape_into(&mut out, src);
    out
}

/// Append the MySQL-escaped form of `src` to `out`.
pub fn mysql_escape_into(out: &mut Vec<u8>, src: &str) {
    for &b in src.as_bytes() {
        if b == b'\'' || b == b'\\' {
            out.push(b);
        }
        out.push(b);
    }
}

/// Strip leading/trailing single quotes from a SQL string value.
pub fn remove_quote(src: &[u8]) -> Vec<u8> {
    remove_quote_slice(src).to_vec()
}

/// Zero-copy variant of `remove_quote`.
pub fn remove_quote_slice(src: &[u8]) -> &[u8] {
    if src.is_empty() {
        return src;
    }
    let mut start = 0;
    let mut end = src.len();
    if src[0] == b'\'' {
        start = 1;
    }
    if end > start && src[end - 1] == b'\'' {
        end -= 1;
    }
    &src[start..end]
}

fn is_escape_char(c: u8) -> bool {
    c == b'\\'
}

fn utf8_char_length(c: u8) -> usize {
    if (c & 0x80) == 0 {
        1
    } else if (c & 0xE0) == 0xC0 {
        2
    } else if (c & 0xF0) == 0xE0 {
        3
    } else if (c & 0xF8) == 0xF0 {
        4
    } else {
        0
    }
}

fn is_utf8_continuation(c: u8) -> bool {
    (c & 0xC0) == 0x80
}

fn is_valid_utf8_sequence(src: &[u8]) -> bool {
    if src.is_empty() {
        return false;
    }
    let expected_len = utf8_char_length(src[0]);
    if expected_len == 0 || expected_len > src.len() {
        return false;
    }
    for i in 1..expected_len {
        if !is_utf8_continuation(src[i]) {
            return false;
        }
    }
    true
}

/// Substring that respects UTF-8 boundaries and escape sequences (\x counts as 1 char).
pub fn mysubstr(src: &[u8], num_chars: usize) -> Vec<u8> {
    let mut result = Vec::new();
    mysubstr_into(&mut result, src, num_chars);
    result
}

/// Same as `mysubstr` but appends into a caller-provided buffer.
pub fn mysubstr_into(result: &mut Vec<u8>, src: &[u8], num_chars: usize) {
    let mut srccount = 0;
    let mut copied_chars = 0;
    let src_len = src.len();

    while srccount < src_len && copied_chars < num_chars {
        if is_escape_char(src[srccount]) {
            if srccount + 1 < src_len {
                result.push(src[srccount]);
                result.push(src[srccount + 1]);
                srccount += 2;
                copied_chars += 1;
            } else {
                break;
            }
        } else {
            let char_length = utf8_char_length(src[srccount]);
            if char_length == 0
                || srccount + char_length > src_len
                || !is_valid_utf8_sequence(&src[srccount..])
            {
                break;
            }
            for i in 0..char_length {
                result.push(src[srccount + i]);
            }
            srccount += char_length;
            copied_chars += 1;
        }
    }
}

/// Compute HMAC-SHA256 and map each byte to the range [begin, end], appending
/// into the caller-provided buffer.
fn make_readable_hash_into(
    out: &mut Vec<u8>,
    token: &[u8],
    secret: &[u8],
    hash_len: usize,
    begin: u8,
    end: u8,
) {
    let mut mac = HmacSha256::new_from_slice(secret).expect("HMAC accepts any key length");
    mac.update(token);
    let result = mac.finalize();
    let digest = result.into_bytes();

    let range = (end - begin + 1) as u8;
    out.reserve(hash_len);
    for i in 0..hash_len {
        out.push((digest[i] % range) + begin);
    }
}

pub fn anonymize_token(
    quoted: bool,
    config: &AnonBase,
    token: &[u8],
    secret: &[u8],
    ctx: Option<&mut AnonContext<'_>>,
) -> AnonResult {
    let mut data = Vec::new();
    let quoting = anonymize_token_into(&mut data, quoted, config, token, secret, ctx);
    AnonResult { data, quoting }
}

/// Hot-path variant: writes the anonymized bytes into the caller-provided buffer
/// (cleared first) and returns just the `QuoteMode`. Avoids per-call allocation
/// of an `AnonResult`/`Vec`.
pub fn anonymize_token_into(
    out: &mut Vec<u8>,
    quoted: bool,
    config: &AnonBase,
    token: &[u8],
    secret: &[u8],
    ctx: Option<&mut AnonContext<'_>>,
) -> QuoteMode {
    out.clear();
    let worktoken = if quoted {
        remove_quote_slice(token)
    } else {
        token
    };

    match config.anon_type {
        AnonType::FixedNull => {
            out.extend_from_slice(b"NULL");
            QuoteMode::ForceFalse
        }

        AnonType::Fixed | AnonType::FixedQuoted | AnonType::FixedUnquoted => {
            mysql_escape_into(out, &config.fixed_value);
            match config.anon_type {
                AnonType::FixedQuoted => QuoteMode::ForceTrue,
                AnonType::FixedUnquoted => QuoteMode::ForceFalse,
                _ => QuoteMode::AsInput,
            }
        }

        AnonType::Key => {
            if let Some(ctx) = ctx {
                ctx.tablekey.clear();
                ctx.tablekey
                    .push_str(&String::from_utf8_lossy(worktoken));
            }
            out.extend_from_slice(worktoken);
            QuoteMode::AsInput
        }

        AnonType::AppendKey => {
            if let Some(c) = ctx.as_deref() {
                if c.tablekey.is_empty() && c.bfirstinsert {
                    eprintln!(
                        "WARNING! Table {} fields order: for appendkey mode, the key must be defined before the field to anonymize",
                        c.tablename
                    );
                }
            }
            out.extend_from_slice(config.fixed_value.as_bytes());
            if let Some(c) = ctx.as_deref() {
                out.extend_from_slice(c.tablekey.as_bytes());
            }
            QuoteMode::ForceTrue
        }

        AnonType::PrependKey => {
            if let Some(c) = ctx.as_deref() {
                if c.tablekey.is_empty() && c.bfirstinsert {
                    eprintln!(
                        "WARNING! Table {} fields order: for prependkey mode, the key must be defined before the field to anonymize",
                        c.tablename
                    );
                }
                out.extend_from_slice(c.tablekey.as_bytes());
            }
            out.extend_from_slice(config.fixed_value.as_bytes());
            QuoteMode::ForceTrue
        }

        AnonType::AppendIndex => {
            let index = ctx.as_deref().map(|c| c.rowindex).unwrap_or(0);
            out.extend_from_slice(config.fixed_value.as_bytes());
            use std::io::Write as _;
            let _ = write!(out, "{}", index);
            QuoteMode::ForceTrue
        }

        AnonType::PrependIndex => {
            let index = ctx.as_deref().map(|c| c.rowindex).unwrap_or(0);
            use std::io::Write as _;
            let _ = write!(out, "{}", index);
            out.extend_from_slice(config.fixed_value.as_bytes());
            QuoteMode::ForceTrue
        }

        AnonType::TextHash => {
            let hash_len = std::cmp::min(32, config.len as usize);
            make_readable_hash_into(out, worktoken, secret, hash_len, b'a', b'z');
            QuoteMode::AsInput
        }

        AnonType::EmailHash => {
            let hash_len = std::cmp::min(32, config.len as usize);
            make_readable_hash_into(out, worktoken, secret, hash_len, b'a', b'z');
            out.push(b'@');
            out.extend_from_slice(config.domain.as_bytes());
            QuoteMode::AsInput
        }

        AnonType::IntHash => {
            let hash_len = std::cmp::min(32, config.len as usize);
            make_readable_hash_into(out, worktoken, secret, hash_len, b'1', b'9');
            QuoteMode::AsInput
        }

        AnonType::Substring => {
            mysubstr_into(out, worktoken, config.len as usize);
            QuoteMode::AsInput
        }

        AnonType::Json | AnonType::Py => {
            // JSON handled at a higher level; Py not implemented
            QuoteMode::AsInput
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_remove_quote() {
        assert_eq!(remove_quote(b"'hello'"), b"hello");
        assert_eq!(remove_quote(b"hello"), b"hello");
        assert_eq!(remove_quote(b"''"), b"");
        assert_eq!(remove_quote(b"'a'"), b"a");
    }

    #[test]
    fn test_mysql_escape() {
        assert_eq!(mysql_escape("hello"), b"hello");
        assert_eq!(mysql_escape("it's"), b"it''s");
        assert_eq!(mysql_escape("a\\b"), b"a\\\\b");
    }

    fn make_readable_hash_test(token: &[u8], secret: &[u8], len: u16, begin: u8, end: u8) -> Vec<u8> {
        let mut out = Vec::new();
        let hash_len = std::cmp::min(32, len as usize);
        make_readable_hash_into(&mut out, token, secret, hash_len, begin, end);
        out
    }

    #[test]
    fn test_make_readable_hash_text() {
        let hash = make_readable_hash_test(b"test", b"lapin", 5, b'a', b'z');
        assert_eq!(hash.len(), 5);
        for &b in &hash {
            assert!(b >= b'a' && b <= b'z');
        }
    }

    #[test]
    fn test_make_readable_hash_int() {
        let hash = make_readable_hash_test(b"test", b"lapin", 3, b'1', b'9');
        assert_eq!(hash.len(), 3);
        for &b in &hash {
            assert!(b >= b'1' && b <= b'9');
        }
    }

    #[test]
    fn test_make_readable_hash_deterministic() {
        let h1 = make_readable_hash_test(b"hello", b"secret", 10, b'a', b'z');
        let h2 = make_readable_hash_test(b"hello", b"secret", 10, b'a', b'z');
        assert_eq!(h1, h2);
    }

    #[test]
    fn test_mysubstr_ascii() {
        assert_eq!(mysubstr(b"hello world", 5), b"hello");
    }

    #[test]
    fn test_mysubstr_escape() {
        // \n\n = two escape sequences, each counting as 1 char
        assert_eq!(mysubstr(b"\\n\\n", 5), b"\\n\\n");
        // \0 sequences
        assert_eq!(
            mysubstr(b"\\0\\0\\0\\0\\0\\0\\0\\0", 5),
            b"\\0\\0\\0\\0\\0"
        );
    }

    #[test]
    fn test_anonymize_fixed_null() {
        let config = AnonBase {
            anon_type: AnonType::FixedNull,
            ..Default::default()
        };
        let result = anonymize_token(false, &config, b"anything", b"secret", None);
        assert_eq!(result.data, b"NULL");
        assert_eq!(result.quoting, QuoteMode::ForceFalse);
    }

    #[test]
    fn test_anonymize_fixed() {
        let config = AnonBase {
            anon_type: AnonType::Fixed,
            fixed_value: "fixedvalue".to_string(),
            ..Default::default()
        };
        let result = anonymize_token(false, &config, b"anything", b"secret", None);
        assert_eq!(result.data, b"fixedvalue");
        assert_eq!(result.quoting, QuoteMode::AsInput);
    }

    #[test]
    fn test_anonymize_key() {
        let config = AnonBase {
            anon_type: AnonType::Key,
            ..Default::default()
        };
        let mut tablekey = String::new();
        let mut ctx = AnonContext {
            tablekey: &mut tablekey,
            rowindex: 0,
            bfirstinsert: true,
            tablename: "test",
        };
        let result = anonymize_token(false, &config, b"42", b"secret", Some(&mut ctx));
        assert_eq!(result.data, b"42");
        assert_eq!(tablekey, "42");
    }

    #[test]
    fn test_anonymize_appendkey() {
        let config = AnonBase {
            anon_type: AnonType::AppendKey,
            fixed_value: "player".to_string(),
            ..Default::default()
        };
        let mut tablekey = "10".to_string();
        let mut ctx = AnonContext {
            tablekey: &mut tablekey,
            rowindex: 0,
            bfirstinsert: false,
            tablename: "test",
        };
        let result = anonymize_token(false, &config, b"Roger", b"secret", Some(&mut ctx));
        assert_eq!(result.data, b"player10");
        assert_eq!(result.quoting, QuoteMode::ForceTrue);
    }
}
