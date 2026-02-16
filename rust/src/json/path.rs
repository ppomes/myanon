use super::types::JsonValue;
use crate::anonymize::anonymize_token;
use crate::config::AnonBase;

/// Check if a JSON path contains wildcards (i.e., `[]`).
pub fn json_path_has_wildcards(path: &str) -> bool {
    path.contains("[]")
}

/// Get a string value at a given JSON path.
pub fn json_get_string_at_path(root: &JsonValue, path: &str) -> Option<String> {
    let path = path.strip_prefix('.').unwrap_or(path);
    get_value_at_path(root, path).and_then(|v| match v {
        JsonValue::String(s) => Some(s.clone()),
        _ => None,
    })
}

fn get_value_at_path<'a>(value: &'a JsonValue, path: &str) -> Option<&'a JsonValue> {
    if path.is_empty() {
        return Some(value);
    }

    // Extract segment
    let (segment, rest) = split_path_segment(path);

    match value {
        JsonValue::Object(members) => {
            for (key, val) in members {
                if key == segment {
                    return get_value_at_path(val, rest);
                }
            }
            None
        }
        JsonValue::Array(elements) => {
            if segment.starts_with('[') {
                let idx_str = &segment[1..segment.len() - 1];
                if let Ok(idx) = idx_str.parse::<usize>() {
                    if idx < elements.len() {
                        return get_value_at_path(&elements[idx], rest);
                    }
                }
            }
            None
        }
        _ => None,
    }
}

/// Replace the string value at a given JSON path.
pub fn json_replace_value_at_path(root: &mut JsonValue, path: &str, new_value: &str) {
    let path = path.strip_prefix('.').unwrap_or(path);
    set_value_at_path(root, path, new_value);
}

fn set_value_at_path(value: &mut JsonValue, path: &str, new_value: &str) -> bool {
    if path.is_empty() {
        if let JsonValue::String(ref mut s) = value {
            *s = new_value.to_string();
            return true;
        }
        return false;
    }

    // Handle array wildcard at start
    if path.starts_with("[]") {
        if let JsonValue::Array(ref mut elements) = value {
            let remaining = &path[2..];
            let remaining = remaining.strip_prefix('.').unwrap_or(remaining);
            let mut any_success = false;
            for elem in elements.iter_mut() {
                if set_value_at_path(elem, remaining, new_value) {
                    any_success = true;
                }
            }
            return any_success;
        }
        return false;
    }

    // Extract segment
    let (segment, rest) = split_path_segment(path);

    match value {
        JsonValue::Object(ref mut members) => {
            for (key, val) in members.iter_mut() {
                if key.as_str() == segment {
                    // Check if rest starts with array access
                    if rest.starts_with('[') {
                        if rest.starts_with("[]") {
                            if let JsonValue::Array(ref mut elements) = val {
                                let remaining = &rest[2..];
                                let remaining =
                                    remaining.strip_prefix('.').unwrap_or(remaining);
                                let mut any_success = false;
                                for elem in elements.iter_mut() {
                                    if set_value_at_path(elem, remaining, new_value) {
                                        any_success = true;
                                    }
                                }
                                return any_success;
                            }
                        } else {
                            // Specific index [n]
                            if let Some(end_bracket) = rest.find(']') {
                                let idx_str = &rest[1..end_bracket];
                                if let Ok(idx) = idx_str.parse::<usize>() {
                                    if let JsonValue::Array(ref mut elements) = val {
                                        if idx < elements.len() {
                                            let remaining = &rest[end_bracket + 1..];
                                            let remaining = remaining
                                                .strip_prefix('.')
                                                .unwrap_or(remaining);
                                            return set_value_at_path(
                                                &mut elements[idx],
                                                remaining,
                                                new_value,
                                            );
                                        }
                                    }
                                }
                            }
                        }
                        return false;
                    } else {
                        return set_value_at_path(val, rest, new_value);
                    }
                }
            }
            false
        }
        JsonValue::Array(ref mut elements) => {
            if segment.starts_with('[') {
                if segment == "[]" {
                    let mut any_success = false;
                    for elem in elements.iter_mut() {
                        if set_value_at_path(elem, rest, new_value) {
                            any_success = true;
                        }
                    }
                    return any_success;
                } else {
                    let idx_str = &segment[1..segment.len() - 1];
                    if let Ok(idx) = idx_str.parse::<usize>() {
                        if idx < elements.len() {
                            return set_value_at_path(&mut elements[idx], rest, new_value);
                        }
                    }
                }
            }
            false
        }
        _ => false,
    }
}

/// Anonymize all string values at a path (supports wildcards).
pub fn json_anonymize_path(
    root: &mut JsonValue,
    path: &str,
    config: &AnonBase,
    secret: &[u8],
) {
    let path = path.strip_prefix('.').unwrap_or(path);
    anonymize_at_path(root, path, config, secret);
}

fn anonymize_at_path(
    value: &mut JsonValue,
    path: &str,
    config: &AnonBase,
    secret: &[u8],
) -> bool {
    if path.is_empty() {
        if let JsonValue::String(ref mut s) = value {
            use crate::config::AnonType;
            if config.anon_type == AnonType::Fixed {
                *s = config.fixed_value.clone();
            } else {
                let res = anonymize_token(false, config, s.as_bytes(), secret, None);
                *s = String::from_utf8_lossy(&res.data).to_string();
            }
            return true;
        }
        return false;
    }

    // Handle array wildcard at start
    if path.starts_with("[]") {
        if let JsonValue::Array(ref mut elements) = value {
            let remaining = &path[2..];
            let remaining = remaining.strip_prefix('.').unwrap_or(remaining);
            let mut any_success = false;
            for elem in elements.iter_mut() {
                if anonymize_at_path(elem, remaining, config, secret) {
                    any_success = true;
                }
            }
            return any_success;
        }
        return false;
    }

    // Extract segment
    let (segment, rest) = split_path_segment(path);

    match value {
        JsonValue::Object(ref mut members) => {
            for (key, val) in members.iter_mut() {
                if key.as_str() == segment {
                    if rest.starts_with('[') {
                        if rest.starts_with("[]") {
                            if let JsonValue::Array(ref mut elements) = val {
                                let remaining = &rest[2..];
                                let remaining =
                                    remaining.strip_prefix('.').unwrap_or(remaining);
                                let mut any_success = false;
                                for elem in elements.iter_mut() {
                                    if anonymize_at_path(
                                        elem, remaining, config, secret,
                                    ) {
                                        any_success = true;
                                    }
                                }
                                return any_success;
                            }
                        }
                        return false;
                    } else {
                        return anonymize_at_path(val, rest, config, secret);
                    }
                }
            }
            false
        }
        JsonValue::Array(ref mut elements) => {
            if segment.starts_with('[') {
                if segment == "[]" {
                    let mut any_success = false;
                    for elem in elements.iter_mut() {
                        if anonymize_at_path(elem, rest, config, secret) {
                            any_success = true;
                        }
                    }
                    return any_success;
                }
            }
            false
        }
        _ => false,
    }
}

/// Split a path into the first segment and the rest.
fn split_path_segment(path: &str) -> (&str, &str) {
    if path.is_empty() {
        return ("", "");
    }

    // Handle array bracket at start
    if path.starts_with('[') {
        if let Some(end) = path.find(']') {
            let segment = &path[..=end];
            let rest = &path[end + 1..];
            let rest = rest.strip_prefix('.').unwrap_or(rest);
            return (segment, rest);
        }
    }

    // Regular field name
    let mut end = path.len();
    for (i, c) in path.char_indices() {
        if c == '.' || c == '[' {
            end = i;
            break;
        }
    }

    let segment = &path[..end];
    let rest = &path[end..];
    let rest = rest.strip_prefix('.').unwrap_or(rest);
    (segment, rest)
}

/// Remove JSON backslash escaping (SQL-stored JSON layer).
/// A single `\` followed by a char: if it's the only backslash, remove it.
/// `\\` becomes `\`.
pub fn remove_json_backslash(src: &str) -> String {
    let bytes = src.as_bytes();
    let len = bytes.len();
    let mut result = Vec::with_capacity(len);
    let mut backslash_count: i32 = 0;

    for i in 0..len {
        if bytes[i] != b'\\' {
            if backslash_count == 1 {
                backslash_count = 0;
            }
            result.push(bytes[i]);
        } else {
            backslash_count += 1;
            if backslash_count % 2 == 0 {
                result.push(b'\\');
                backslash_count = 0;
            }
        }
    }

    String::from_utf8(result).unwrap_or_default()
}

/// Add JSON backslash escaping for SQL output.
pub fn add_json_backslash(src: &str) -> String {
    let mut result = String::with_capacity(src.len() * 2);
    for c in src.chars() {
        let needs_escape = c == '"' || c == '\'' || c == '\\' || c == '\x08' || c == '\r' || c == '\t';
        if needs_escape {
            result.push('\\');
        }
        result.push(c);
    }
    result
}

/// Serialize a JSON value to a compact JSON string (no spaces after `:` or `,`).
pub fn json_to_string(value: &JsonValue) -> String {
    let mut buf = String::new();
    json_to_string_internal(value, &mut buf);
    buf
}

fn json_to_string_internal(value: &JsonValue, buf: &mut String) {
    match value {
        JsonValue::String(s) => {
            buf.push('"');
            // Strings already contain escape sequences from parsing, output as-is
            buf.push_str(s);
            buf.push('"');
        }
        JsonValue::Int(n) => {
            buf.push_str(&n.to_string());
        }
        JsonValue::Float(f) => {
            // Match C behavior: if integer value, print as integer
            if *f == (*f as i64) as f64 {
                buf.push_str(&(*f as i64).to_string());
            } else {
                buf.push_str(&format!("{}", f));
            }
        }
        JsonValue::Bool(b) => {
            buf.push_str(if *b { "true" } else { "false" });
        }
        JsonValue::Null => {
            buf.push_str("null");
        }
        JsonValue::Object(members) => {
            buf.push('{');
            for (i, (key, val)) in members.iter().enumerate() {
                if i > 0 {
                    buf.push(',');
                }
                buf.push('"');
                buf.push_str(key);
                buf.push_str("\":");
                json_to_string_internal(val, buf);
            }
            buf.push('}');
        }
        JsonValue::Array(elements) => {
            buf.push('[');
            for (i, elem) in elements.iter().enumerate() {
                if i > 0 {
                    buf.push(',');
                }
                json_to_string_internal(elem, buf);
            }
            buf.push(']');
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::json::parser::json_parse_string;

    #[test]
    fn test_json_to_string_roundtrip() {
        let input = r#"{"key":"value"}"#;
        let parsed = json_parse_string(input).unwrap();
        let output = json_to_string(&parsed);
        assert_eq!(output, input);
    }

    #[test]
    fn test_json_to_string_complex() {
        let input = r#"{"email":"test@test.com","last_name":"Doe","first_name":"Tom"}"#;
        let parsed = json_parse_string(input).unwrap();
        let output = json_to_string(&parsed);
        assert_eq!(output, input);
    }

    #[test]
    fn test_json_to_string_array() {
        let input = r#"["a","b","c"]"#;
        let parsed = json_parse_string(input).unwrap();
        let output = json_to_string(&parsed);
        assert_eq!(output, input);
    }

    #[test]
    fn test_get_string_at_path() {
        let parsed = json_parse_string(r#"{"email":"test@test.com","name":"John"}"#).unwrap();
        assert_eq!(
            json_get_string_at_path(&parsed, "email"),
            Some("test@test.com".to_string())
        );
        assert_eq!(
            json_get_string_at_path(&parsed, "name"),
            Some("John".to_string())
        );
        assert_eq!(json_get_string_at_path(&parsed, "missing"), None);
    }

    #[test]
    fn test_replace_value_at_path() {
        let mut parsed =
            json_parse_string(r#"{"email":"test@test.com","name":"John"}"#).unwrap();
        json_replace_value_at_path(&mut parsed, "name", "anon");
        assert_eq!(json_get_string_at_path(&parsed, "name"), Some("anon".to_string()));
    }

    #[test]
    fn test_path_has_wildcards() {
        assert!(json_path_has_wildcards("items[]"));
        assert!(json_path_has_wildcards("email_changes[][]"));
        assert!(json_path_has_wildcards("[]"));
        assert!(!json_path_has_wildcards("email"));
        assert!(!json_path_has_wildcards("contact.email"));
    }

    #[test]
    fn test_remove_json_backslash() {
        assert_eq!(remove_json_backslash(r#"hello"#), "hello");
        assert_eq!(remove_json_backslash(r#"a\"b"#), r#"a"b"#);
        assert_eq!(remove_json_backslash(r#"a\\b"#), r#"a\b"#);
        assert_eq!(remove_json_backslash(r#"end\\"#), r#"end\"#);
    }

    #[test]
    fn test_add_json_backslash() {
        assert_eq!(add_json_backslash("hello"), "hello");
        assert_eq!(add_json_backslash(r#"a"b"#), r#"a\"b"#);
        assert_eq!(add_json_backslash(r#"a\b"#), r#"a\\b"#);
    }

    #[test]
    fn test_json_to_string_with_spaces_in_input() {
        // Input with spaces after : and ,
        let input = r#"{"key": "value", "arr": [1, 2]}"#;
        let parsed = json_parse_string(input).unwrap();
        let output = json_to_string(&parsed);
        // Output should be compact (no spaces)
        assert_eq!(output, r#"{"key":"value","arr":[1,2]}"#);
    }
}
