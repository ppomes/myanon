use regex::Regex;

/// Maximum anonymization output length (matches C MAX_LEN)
pub const MAX_LEN: u16 = 32;

/// Anonymization type — matches C anon_type enum
#[derive(Debug, Clone, PartialEq)]
pub enum AnonType {
    FixedNull,
    Fixed,
    FixedQuoted,
    FixedUnquoted,
    TextHash,
    EmailHash,
    IntHash,
    Key,
    AppendKey,
    PrependKey,
    AppendIndex,
    PrependIndex,
    Substring,
    Json,
    Py,
}

/// Table action — matches C table_action_st enum
#[derive(Debug, Clone, PartialEq)]
pub enum TableAction {
    Truncate,
    Anon,
}

/// Base anonymization info — matches C anon_base_st
#[derive(Debug, Clone)]
pub struct AnonBase {
    pub anon_type: AnonType,
    pub len: u16,
    pub domain: String,
    pub separator: Option<char>,
    pub fixed_value: String,
    pub pydef: String,
    pub nbhits: u64,
}

impl Default for AnonBase {
    fn default() -> Self {
        AnonBase {
            anon_type: AnonType::FixedNull,
            len: 0,
            domain: String::new(),
            separator: None,
            fixed_value: String::new(),
            pydef: String::new(),
            nbhits: 0,
        }
    }
}

/// JSON path anonymization — matches C anon_json_st
#[derive(Debug, Clone)]
pub struct AnonJson {
    pub filter: String,
    pub infos: AnonBase,
}

/// Field anonymization — matches C anon_field_st
#[derive(Debug, Clone)]
pub struct AnonField {
    pub name: String,
    pub pos: i32,
    pub quoted: bool,
    pub infos: AnonBase,
    pub json: Vec<AnonJson>,
}

/// Table config — matches C anon_table_st
#[derive(Debug)]
pub struct AnonTable {
    pub name: String,
    pub regex: Option<Regex>,
    pub action: TableAction,
    pub fields: Vec<AnonField>,
}

/// Top-level config
#[derive(Debug)]
pub struct Config {
    pub secret: String,
    pub stats: bool,
    pub pypath: String,
    pub pyscript: String,
    pub tables: Vec<AnonTable>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            secret: String::new(),
            stats: false,
            pypath: String::new(),
            pyscript: String::new(),
            tables: Vec::new(),
        }
    }
}

/// Validates a JSON path string.
/// Valid characters: alphanumeric, underscore, dot, brackets `[` and `]`.
pub fn is_valid_json_path(path: &str) -> bool {
    let mut chars = path.chars().peekable();
    while let Some(c) = chars.next() {
        match c {
            'a'..='z' | 'A'..='Z' | '0'..='9' | '_' | '.' => {}
            '[' => {
                if chars.next() != Some(']') {
                    return false;
                }
            }
            _ => return false,
        }
    }
    true
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_json_paths() {
        assert!(is_valid_json_path("name"));
        assert!(is_valid_json_path("email"));
        assert!(is_valid_json_path("last_name"));
        assert!(is_valid_json_path("contact.email"));
        assert!(is_valid_json_path("items[]"));
        assert!(is_valid_json_path("email_changes[][]"));
        assert!(is_valid_json_path("[]"));
        assert!(is_valid_json_path(".full_name"));
    }

    #[test]
    fn test_invalid_json_paths() {
        assert!(!is_valid_json_path("foo[bar]"));
        assert!(!is_valid_json_path("foo bar"));
        assert!(!is_valid_json_path("foo@bar"));
    }
}
