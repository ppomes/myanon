use crate::config::types::MAX_LEN;
use std::fmt;

/// Token types produced by the lexer
#[derive(Debug, Clone, PartialEq)]
pub enum Token {
    // Keywords
    Secret,
    Stats,
    PyPath,
    PyScript,
    Tables,
    Yes,
    No,
    Fixed,
    FixedNull,
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
    Truncate,
    PyDef,
    Json,
    Path,
    SeparatedBy,
    Regex,
    // Values
    Str(String),
    Ident(String),
    Length(u16),
    // Symbols
    Eq,
    LBrace,
    RBrace,
    // End
    Eof,
}

impl fmt::Display for Token {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Token::Secret => write!(f, "secret"),
            Token::Stats => write!(f, "stats"),
            Token::PyPath => write!(f, "pypath"),
            Token::PyScript => write!(f, "pyscript"),
            Token::Tables => write!(f, "tables"),
            Token::Yes => write!(f, "'yes'"),
            Token::No => write!(f, "'no'"),
            Token::Fixed => write!(f, "fixed"),
            Token::FixedNull => write!(f, "fixed null"),
            Token::FixedQuoted => write!(f, "fixed quoted"),
            Token::FixedUnquoted => write!(f, "fixed unquoted"),
            Token::TextHash => write!(f, "texthash"),
            Token::EmailHash => write!(f, "emailhash"),
            Token::IntHash => write!(f, "inthash"),
            Token::Key => write!(f, "key"),
            Token::AppendKey => write!(f, "appendkey"),
            Token::PrependKey => write!(f, "prependkey"),
            Token::AppendIndex => write!(f, "appendindex"),
            Token::PrependIndex => write!(f, "prependindex"),
            Token::Substring => write!(f, "substring"),
            Token::Truncate => write!(f, "truncate"),
            Token::PyDef => write!(f, "pydef"),
            Token::Json => write!(f, "json"),
            Token::Path => write!(f, "path"),
            Token::SeparatedBy => write!(f, "separated by"),
            Token::Regex => write!(f, "regex"),
            Token::Str(s) => write!(f, "'{}'", s),
            Token::Ident(s) => write!(f, "`{}`", s),
            Token::Length(n) => write!(f, "{}", n),
            Token::Eq => write!(f, "="),
            Token::LBrace => write!(f, "{{"),
            Token::RBrace => write!(f, "}}"),
            Token::Eof => write!(f, "end of file"),
        }
    }
}

pub struct Lexer {
    input: Vec<char>,
    pos: usize,
    pub line: usize,
}

impl Lexer {
    pub fn new(input: &str) -> Self {
        Lexer {
            input: input.chars().collect(),
            pos: 0,
            line: 1,
        }
    }

    fn peek(&self) -> Option<char> {
        self.input.get(self.pos).copied()
    }

    fn advance(&mut self) -> Option<char> {
        let ch = self.input.get(self.pos).copied();
        if let Some(c) = ch {
            self.pos += 1;
            if c == '\n' {
                self.line += 1;
            }
        }
        ch
    }

    fn skip_whitespace_and_comments(&mut self) {
        loop {
            match self.peek() {
                Some(' ') | Some('\t') | Some('\r') | Some('\n') => {
                    self.advance();
                }
                Some('#') => {
                    // Skip until end of line
                    while let Some(c) = self.advance() {
                        if c == '\n' {
                            break;
                        }
                    }
                }
                _ => break,
            }
        }
    }

    /// Read a single-quoted string, returning contents without quotes.
    fn read_string(&mut self) -> Result<String, String> {
        // Opening quote already consumed
        let mut s = String::new();
        loop {
            match self.advance() {
                Some('\'') => return Ok(s),
                Some(c) => {
                    if s.len() >= 1024 {
                        return Err(format!(
                            "Config parsing error at line {}: string too long (max 1024 characters)",
                            self.line
                        ));
                    }
                    s.push(c);
                }
                None => {
                    return Err(format!(
                        "Config parsing error at line {}: unterminated string",
                        self.line
                    ));
                }
            }
        }
    }

    /// Read a backtick-quoted identifier, returning contents without backticks.
    fn read_identifier(&mut self) -> Result<String, String> {
        // Opening backtick already consumed
        let mut s = String::new();
        loop {
            match self.advance() {
                Some('`') => {
                    if s.is_empty() {
                        return Err(format!(
                            "Config parsing error at line {}: empty identifier",
                            self.line
                        ));
                    }
                    return Ok(s);
                }
                Some(c) => {
                    if s.len() >= 64 {
                        return Err(format!(
                            "Config parsing error at line {}: identifier too long (max 64 characters)",
                            self.line
                        ));
                    }
                    s.push(c);
                }
                None => {
                    return Err(format!(
                        "Config parsing error at line {}: unterminated identifier",
                        self.line
                    ));
                }
            }
        }
    }

    /// Read a bare word (keyword).
    fn read_word(&mut self, first: char) -> String {
        let mut s = String::new();
        s.push(first);
        while let Some(c) = self.peek() {
            if c.is_ascii_alphanumeric() || c == '_' {
                s.push(c);
                self.advance();
            } else {
                break;
            }
        }
        s
    }

    /// Read a numeric length value.
    fn read_number(&mut self, first: char) -> Result<Token, String> {
        let mut s = String::new();
        s.push(first);
        while let Some(c) = self.peek() {
            if c.is_ascii_digit() {
                s.push(c);
                self.advance();
            } else {
                break;
            }
        }
        let n: u16 = s.parse().map_err(|_| {
            format!(
                "Config parsing error at line {}: invalid number '{}'",
                self.line, s
            )
        })?;
        if n == 0 || n > MAX_LEN {
            return Err(format!(
                "Config parsing error at line {}: Requested length is too long",
                self.line
            ));
        }
        Ok(Token::Length(n))
    }

    /// Check if the upcoming non-whitespace word matches `expected`, and if so consume it.
    /// Used for two-word keywords like "fixed null", "separated by".
    fn try_consume_word(&mut self, expected: &str) -> bool {
        let saved_pos = self.pos;
        let saved_line = self.line;
        // Skip spaces/tabs only (not newlines or comments)
        while let Some(c) = self.peek() {
            if c == ' ' || c == '\t' {
                self.advance();
            } else {
                break;
            }
        }
        // Try to read the word
        if let Some(first) = self.peek() {
            if first.is_ascii_alphabetic() {
                let start = self.pos;
                let word_start_line = self.line;
                self.advance();
                let word = self.read_word(first);
                if word == expected {
                    return true;
                }
                // Restore position — word didn't match
                self.pos = start;
                self.line = word_start_line;
                return false;
            }
        }
        // Restore
        self.pos = saved_pos;
        self.line = saved_line;
        false
    }

    fn keyword_token(&mut self, word: &str) -> Result<Token, String> {
        match word {
            "secret" => Ok(Token::Secret),
            "stats" => Ok(Token::Stats),
            "pypath" => Ok(Token::PyPath),
            "pyscript" => Ok(Token::PyScript),
            "tables" => Ok(Token::Tables),
            "texthash" => Ok(Token::TextHash),
            "emailhash" => Ok(Token::EmailHash),
            "inthash" => Ok(Token::IntHash),
            "key" => Ok(Token::Key),
            "appendkey" => Ok(Token::AppendKey),
            "prependkey" => Ok(Token::PrependKey),
            "appendindex" => Ok(Token::AppendIndex),
            "prependindex" => Ok(Token::PrependIndex),
            "substring" => Ok(Token::Substring),
            "truncate" => Ok(Token::Truncate),
            "pydef" => Ok(Token::PyDef),
            "json" => Ok(Token::Json),
            "path" => Ok(Token::Path),
            "regex" => Ok(Token::Regex),
            "fixed" => {
                // Check for two-word variants: "fixed null", "fixed quoted", "fixed unquoted"
                if self.try_consume_word("null") {
                    Ok(Token::FixedNull)
                } else if self.try_consume_word("quoted") {
                    Ok(Token::FixedQuoted)
                } else if self.try_consume_word("unquoted") {
                    Ok(Token::FixedUnquoted)
                } else {
                    Ok(Token::Fixed)
                }
            }
            "separated" => {
                if self.try_consume_word("by") {
                    Ok(Token::SeparatedBy)
                } else {
                    Err(format!(
                        "Config parsing error at line {}: expected 'by' after 'separated'",
                        self.line
                    ))
                }
            }
            _ => Err(format!(
                "Config parsing error at line {}: unexpected keyword '{}'",
                self.line, word
            )),
        }
    }

    /// Get the next token.
    pub fn next_token(&mut self) -> Result<Token, String> {
        self.skip_whitespace_and_comments();

        match self.peek() {
            None => Ok(Token::Eof),
            Some('=') => {
                self.advance();
                Ok(Token::Eq)
            }
            Some('{') => {
                self.advance();
                Ok(Token::LBrace)
            }
            Some('}') => {
                self.advance();
                Ok(Token::RBrace)
            }
            Some('\'') => {
                self.advance();
                let s = self.read_string()?;
                // Check for special string tokens 'yes' and 'no'
                if s == "yes" {
                    Ok(Token::Yes)
                } else if s == "no" {
                    Ok(Token::No)
                } else {
                    Ok(Token::Str(s))
                }
            }
            Some('`') => {
                self.advance();
                let s = self.read_identifier()?;
                Ok(Token::Ident(s))
            }
            Some(c) if c.is_ascii_digit() => {
                self.advance();
                self.read_number(c)
            }
            Some(c) if c.is_ascii_alphabetic() || c == '_' => {
                self.advance();
                let word = self.read_word(c);
                self.keyword_token(&word)
            }
            Some(c) => Err(format!(
                "Config parsing error at line {}: Syntax error near '{}'",
                self.line, c
            )),
        }
    }

    /// Peek at the next token without consuming it.
    /// Returns the token and restores the lexer position.
    pub fn peek_token(&mut self) -> Result<Token, String> {
        let saved_pos = self.pos;
        let saved_line = self.line;
        let tok = self.next_token()?;
        self.pos = saved_pos;
        self.line = saved_line;
        Ok(tok)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_tokens() {
        let mut lex = Lexer::new("secret = 'hello'");
        assert_eq!(lex.next_token().unwrap(), Token::Secret);
        assert_eq!(lex.next_token().unwrap(), Token::Eq);
        assert_eq!(lex.next_token().unwrap(), Token::Str("hello".into()));
        assert_eq!(lex.next_token().unwrap(), Token::Eof);
    }

    #[test]
    fn test_yes_no() {
        let mut lex = Lexer::new("'yes' 'no'");
        assert_eq!(lex.next_token().unwrap(), Token::Yes);
        assert_eq!(lex.next_token().unwrap(), Token::No);
    }

    #[test]
    fn test_fixed_variants() {
        let mut lex = Lexer::new("fixed null fixed quoted fixed unquoted fixed");
        assert_eq!(lex.next_token().unwrap(), Token::FixedNull);
        assert_eq!(lex.next_token().unwrap(), Token::FixedQuoted);
        assert_eq!(lex.next_token().unwrap(), Token::FixedUnquoted);
        assert_eq!(lex.next_token().unwrap(), Token::Fixed);
    }

    #[test]
    fn test_separated_by() {
        let mut lex = Lexer::new("separated by ','");
        assert_eq!(lex.next_token().unwrap(), Token::SeparatedBy);
        assert_eq!(lex.next_token().unwrap(), Token::Str(",".into()));
    }

    #[test]
    fn test_identifier() {
        let mut lex = Lexer::new("`my_table`");
        assert_eq!(lex.next_token().unwrap(), Token::Ident("my_table".into()));
    }

    #[test]
    fn test_length() {
        let mut lex = Lexer::new("32");
        assert_eq!(lex.next_token().unwrap(), Token::Length(32));
    }

    #[test]
    fn test_length_too_long() {
        let mut lex = Lexer::new("33");
        assert!(lex.next_token().is_err());
    }

    #[test]
    fn test_comments_and_whitespace() {
        let mut lex = Lexer::new("# comment\nsecret  # inline\n= 'x'");
        assert_eq!(lex.next_token().unwrap(), Token::Secret);
        assert_eq!(lex.next_token().unwrap(), Token::Eq);
        assert_eq!(lex.next_token().unwrap(), Token::Str("x".into()));
    }

    #[test]
    fn test_line_tracking() {
        let mut lex = Lexer::new("secret\n=\n'val'");
        lex.next_token().unwrap();
        assert_eq!(lex.line, 1);
        lex.next_token().unwrap();
        assert_eq!(lex.line, 2);
        lex.next_token().unwrap();
        assert_eq!(lex.line, 3);
    }

    #[test]
    fn test_regex_keyword() {
        let mut lex = Lexer::new("regex `pattern`");
        assert_eq!(lex.next_token().unwrap(), Token::Regex);
        assert_eq!(lex.next_token().unwrap(), Token::Ident("pattern".into()));
    }

    #[test]
    fn test_empty_string() {
        let mut lex = Lexer::new("''");
        assert_eq!(lex.next_token().unwrap(), Token::Str("".into()));
    }
}
