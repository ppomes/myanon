use super::types::JsonValue;

#[derive(Debug, Clone, PartialEq)]
enum Token {
    LBrace,
    RBrace,
    LBracket,
    RBracket,
    Comma,
    Colon,
    String(String),
    NumberInt(i64),
    NumberFloat(f64),
    True,
    False,
    Null,
    Eof,
}

struct Lexer<'a> {
    input: &'a [u8],
    pos: usize,
}

impl<'a> Lexer<'a> {
    fn new(input: &'a [u8]) -> Self {
        Lexer { input, pos: 0 }
    }

    fn peek_byte(&self) -> Option<u8> {
        if self.pos < self.input.len() {
            Some(self.input[self.pos])
        } else {
            None
        }
    }

    fn advance(&mut self) -> Option<u8> {
        if self.pos < self.input.len() {
            let b = self.input[self.pos];
            self.pos += 1;
            Some(b)
        } else {
            None
        }
    }

    fn skip_whitespace(&mut self) {
        while let Some(b) = self.peek_byte() {
            if b == b' ' || b == b'\t' || b == b'\r' || b == b'\n' {
                self.pos += 1;
            } else {
                break;
            }
        }
    }

    fn read_string(&mut self) -> Result<String, String> {
        // opening " already consumed
        let mut s = String::new();
        loop {
            match self.advance() {
                None => return Err("Unterminated string".to_string()),
                Some(b'"') => return Ok(s),
                Some(b'\\') => {
                    // Copy escape sequences literally (matching C behavior)
                    s.push('\\');
                    match self.advance() {
                        None => return Err("Unterminated string escape".to_string()),
                        Some(c) => s.push(c as char),
                    }
                }
                Some(c) => s.push(c as char),
            }
        }
    }

    fn read_number(&mut self, first: u8) -> Result<Token, String> {
        let mut s = String::new();
        s.push(first as char);
        let mut is_float = false;

        while let Some(b) = self.peek_byte() {
            match b {
                b'0'..=b'9' => {
                    s.push(b as char);
                    self.pos += 1;
                }
                b'.' => {
                    is_float = true;
                    s.push('.');
                    self.pos += 1;
                }
                b'e' | b'E' => {
                    is_float = true;
                    s.push(b as char);
                    self.pos += 1;
                    if let Some(b'+') | Some(b'-') = self.peek_byte() {
                        s.push(self.advance().unwrap() as char);
                    }
                }
                _ => break,
            }
        }

        if is_float {
            match s.parse::<f64>() {
                Ok(v) => Ok(Token::NumberFloat(v)),
                Err(_) => Err(format!("Invalid float: {}", s)),
            }
        } else {
            match s.parse::<i64>() {
                Ok(v) => Ok(Token::NumberInt(v)),
                Err(_) => Err(format!("Invalid integer: {}", s)),
            }
        }
    }

    fn next_token(&mut self) -> Result<Token, String> {
        self.skip_whitespace();
        match self.advance() {
            None => Ok(Token::Eof),
            Some(b'{') => Ok(Token::LBrace),
            Some(b'}') => Ok(Token::RBrace),
            Some(b'[') => Ok(Token::LBracket),
            Some(b']') => Ok(Token::RBracket),
            Some(b',') => Ok(Token::Comma),
            Some(b':') => Ok(Token::Colon),
            Some(b'"') => {
                let s = self.read_string()?;
                Ok(Token::String(s))
            }
            Some(b't') => {
                // true
                if self.input.get(self.pos..self.pos + 3) == Some(b"rue") {
                    self.pos += 3;
                    Ok(Token::True)
                } else {
                    Err("Expected 'true'".to_string())
                }
            }
            Some(b'f') => {
                // false
                if self.input.get(self.pos..self.pos + 4) == Some(b"alse") {
                    self.pos += 4;
                    Ok(Token::False)
                } else {
                    Err("Expected 'false'".to_string())
                }
            }
            Some(b'n') => {
                // null
                if self.input.get(self.pos..self.pos + 3) == Some(b"ull") {
                    self.pos += 3;
                    Ok(Token::Null)
                } else {
                    Err("Expected 'null'".to_string())
                }
            }
            Some(c @ b'0'..=b'9') | Some(c @ b'-') => self.read_number(c),
            Some(c) => Err(format!("Unexpected character: {}", c as char)),
        }
    }
}

struct Parser<'a> {
    lexer: Lexer<'a>,
    current: Token,
}

impl<'a> Parser<'a> {
    fn new(input: &'a [u8]) -> Result<Self, String> {
        let mut lexer = Lexer::new(input);
        let current = lexer.next_token()?;
        Ok(Parser { lexer, current })
    }

    fn advance(&mut self) -> Result<(), String> {
        self.current = self.lexer.next_token()?;
        Ok(())
    }

    fn parse_value(&mut self) -> Result<JsonValue, String> {
        match &self.current {
            Token::LBrace => self.parse_object(),
            Token::LBracket => self.parse_array(),
            Token::String(s) => {
                let val = JsonValue::String(s.clone());
                self.advance()?;
                Ok(val)
            }
            Token::NumberInt(n) => {
                let val = JsonValue::Int(*n);
                self.advance()?;
                Ok(val)
            }
            Token::NumberFloat(f) => {
                let val = JsonValue::Float(*f);
                self.advance()?;
                Ok(val)
            }
            Token::True => {
                self.advance()?;
                Ok(JsonValue::Bool(true))
            }
            Token::False => {
                self.advance()?;
                Ok(JsonValue::Bool(false))
            }
            Token::Null => {
                self.advance()?;
                Ok(JsonValue::Null)
            }
            _ => Err(format!("Unexpected token: {:?}", self.current)),
        }
    }

    fn parse_object(&mut self) -> Result<JsonValue, String> {
        // consume '{'
        self.advance()?;
        let mut members = Vec::new();

        if self.current == Token::RBrace {
            self.advance()?;
            return Ok(JsonValue::Object(members));
        }

        loop {
            let key = match &self.current {
                Token::String(s) => s.clone(),
                _ => return Err(format!("Expected string key, got {:?}", self.current)),
            };
            self.advance()?;

            if self.current != Token::Colon {
                return Err("Expected ':'".to_string());
            }
            self.advance()?;

            let value = self.parse_value()?;
            members.push((key, value));

            if self.current == Token::RBrace {
                self.advance()?;
                return Ok(JsonValue::Object(members));
            }

            if self.current != Token::Comma {
                return Err("Expected ',' or '}'".to_string());
            }
            self.advance()?;
        }
    }

    fn parse_array(&mut self) -> Result<JsonValue, String> {
        // consume '['
        self.advance()?;
        let mut elements = Vec::new();

        if self.current == Token::RBracket {
            self.advance()?;
            return Ok(JsonValue::Array(elements));
        }

        loop {
            let value = self.parse_value()?;
            elements.push(value);

            if self.current == Token::RBracket {
                self.advance()?;
                return Ok(JsonValue::Array(elements));
            }

            if self.current != Token::Comma {
                return Err("Expected ',' or ']'".to_string());
            }
            self.advance()?;
        }
    }
}

pub fn json_parse_string(input: &str) -> Option<JsonValue> {
    let mut parser = match Parser::new(input.as_bytes()) {
        Ok(p) => p,
        Err(_) => return None,
    };
    match parser.parse_value() {
        Ok(v) => Some(v),
        Err(_) => None,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_simple_object() {
        let json = json_parse_string(r#"{"key": "value"}"#).unwrap();
        match json {
            JsonValue::Object(members) => {
                assert_eq!(members.len(), 1);
                assert_eq!(members[0].0, "key");
                match &members[0].1 {
                    JsonValue::String(s) => assert_eq!(s, "value"),
                    _ => panic!("Expected string"),
                }
            }
            _ => panic!("Expected object"),
        }
    }

    #[test]
    fn test_parse_array() {
        let json = json_parse_string(r#"["a", "b", "c"]"#).unwrap();
        match json {
            JsonValue::Array(elems) => {
                assert_eq!(elems.len(), 3);
            }
            _ => panic!("Expected array"),
        }
    }

    #[test]
    fn test_parse_nested() {
        let json =
            json_parse_string(r#"{"email": "test@test.com", "last_name": "Doe"}"#).unwrap();
        match json {
            JsonValue::Object(members) => {
                assert_eq!(members.len(), 2);
            }
            _ => panic!("Expected object"),
        }
    }

    #[test]
    fn test_parse_with_escapes() {
        let json = json_parse_string(r#"{"title": "It is time for \"fun\"!"}"#).unwrap();
        match json {
            JsonValue::Object(members) => {
                match &members[0].1 {
                    JsonValue::String(s) => {
                        assert_eq!(s, r#"It is time for \"fun\"!"#);
                    }
                    _ => panic!("Expected string"),
                }
            }
            _ => panic!("Expected object"),
        }
    }

    #[test]
    fn test_parse_numbers() {
        let json = json_parse_string(r#"{"int": 42, "float": 3.14}"#).unwrap();
        match json {
            JsonValue::Object(members) => {
                match &members[0].1 {
                    JsonValue::Int(n) => assert_eq!(*n, 42),
                    _ => panic!("Expected int"),
                }
                match &members[1].1 {
                    JsonValue::Float(f) => assert!((f - 3.14).abs() < 0.001),
                    _ => panic!("Expected float"),
                }
            }
            _ => panic!("Expected object"),
        }
    }

    #[test]
    fn test_parse_booleans_null() {
        let json = json_parse_string(r#"{"a": true, "b": false, "c": null}"#).unwrap();
        match json {
            JsonValue::Object(members) => {
                assert!(matches!(&members[0].1, JsonValue::Bool(true)));
                assert!(matches!(&members[1].1, JsonValue::Bool(false)));
                assert!(matches!(&members[2].1, JsonValue::Null));
            }
            _ => panic!("Expected object"),
        }
    }
}
