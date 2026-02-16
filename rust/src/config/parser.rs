use crate::config::lexer::{Lexer, Token};
use crate::config::types::*;

pub struct Parser {
    lexer: Lexer,
}

impl Parser {
    pub fn new(input: &str) -> Self {
        Parser {
            lexer: Lexer::new(input),
        }
    }

    fn error(&self, msg: &str) -> String {
        format!("Config parsing error at line {}: {}", self.lexer.line, msg)
    }

    fn expect(&mut self, expected: &Token) -> Result<Token, String> {
        let tok = self.lexer.next_token()?;
        if std::mem::discriminant(&tok) == std::mem::discriminant(expected) {
            Ok(tok)
        } else {
            Err(self.error(&format!("expected {}, got {}", expected, tok)))
        }
    }

    fn expect_eq(&mut self) -> Result<(), String> {
        self.expect(&Token::Eq)?;
        Ok(())
    }

    fn expect_lbrace(&mut self) -> Result<(), String> {
        self.expect(&Token::LBrace)?;
        Ok(())
    }

    fn expect_string(&mut self) -> Result<String, String> {
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Str(s) => Ok(s),
            _ => Err(self.error(&format!("expected string, got {}", tok))),
        }
    }

    fn expect_ident(&mut self) -> Result<String, String> {
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Ident(s) => Ok(s),
            _ => Err(self.error(&format!("expected identifier, got {}", tok))),
        }
    }

    fn expect_length(&mut self) -> Result<u16, String> {
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Length(n) => Ok(n),
            _ => Err(self.error(&format!("expected length, got {}", tok))),
        }
    }

    pub fn parse(&mut self) -> Result<Config, String> {
        let mut config = Config::default();

        loop {
            let tok = self.lexer.next_token()?;
            match tok {
                Token::Eof => break,
                Token::Secret => self.parse_secret(&mut config)?,
                Token::Stats => self.parse_stats(&mut config)?,
                Token::PyPath => self.parse_pypath(&mut config)?,
                Token::PyScript => self.parse_pyscript(&mut config)?,
                Token::Tables => self.parse_tables(&mut config)?,
                _ => return Err(self.error(&format!("unexpected token {}", tok))),
            }
        }

        Ok(config)
    }

    fn parse_secret(&mut self, config: &mut Config) -> Result<(), String> {
        self.expect_eq()?;
        config.secret = self.expect_string()?;
        Ok(())
    }

    fn parse_stats(&mut self, config: &mut Config) -> Result<(), String> {
        self.expect_eq()?;
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Yes => config.stats = true,
            Token::No => config.stats = false,
            _ => return Err(self.error(&format!("expected 'yes' or 'no', got {}", tok))),
        }
        Ok(())
    }

    fn parse_pypath(&mut self, config: &mut Config) -> Result<(), String> {
        self.expect_eq()?;
        config.pypath = self.expect_string()?;
        Ok(())
    }

    fn parse_pyscript(&mut self, config: &mut Config) -> Result<(), String> {
        self.expect_eq()?;
        config.pyscript = self.expect_string()?;
        Ok(())
    }

    fn parse_tables(&mut self, config: &mut Config) -> Result<(), String> {
        self.expect_eq()?;
        self.expect_lbrace()?;

        loop {
            let tok = self.lexer.next_token()?;
            match tok {
                Token::RBrace => break,
                Token::Regex => {
                    let name = self.expect_ident()?;
                    let line = self.lexer.line;
                    self.check_duplicate_table(config, &name, line)?;
                    let compiled = regex::Regex::new(&name).map_err(|e| {
                        format!(
                            "Config parsing error at line {}: Unable to compile regex '{}': {}",
                            line, name, e
                        )
                    })?;
                    self.expect_eq()?;
                    let table = self.parse_table_action(&name, Some(compiled))?;
                    config.tables.push(table);
                }
                Token::Ident(name) => {
                    let line = self.lexer.line;
                    self.check_duplicate_table(config, &name, line)?;
                    self.expect_eq()?;
                    let table = self.parse_table_action(&name, None)?;
                    config.tables.push(table);
                }
                _ => return Err(self.error(&format!("expected table name or '}}', got {}", tok))),
            }
        }

        Ok(())
    }

    fn check_duplicate_table(
        &self,
        config: &Config,
        name: &str,
        line: usize,
    ) -> Result<(), String> {
        if config.tables.iter().any(|t| t.name == name) {
            return Err(format!(
                "Error: table {} is defined more than once in config file at line {}",
                name, line
            ));
        }
        Ok(())
    }

    fn parse_table_action(
        &mut self,
        name: &str,
        regex: Option<regex::Regex>,
    ) -> Result<AnonTable, String> {
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Truncate => Ok(AnonTable {
                name: name.to_string(),
                regex,
                action: TableAction::Truncate,
                fields: Vec::new(),
            }),
            Token::LBrace => {
                let fields = self.parse_field_list(name)?;
                Ok(AnonTable {
                    name: name.to_string(),
                    regex,
                    action: TableAction::Anon,
                    fields,
                })
            }
            _ => Err(self.error(&format!("expected 'truncate' or '{{', got {}", tok))),
        }
    }

    fn parse_field_list(&mut self, table_name: &str) -> Result<Vec<AnonField>, String> {
        let mut fields = Vec::new();

        loop {
            let tok = self.lexer.next_token()?;
            match tok {
                Token::RBrace => break,
                Token::Ident(field_name) => {
                    let line = self.lexer.line;
                    // Check duplicate field
                    if fields.iter().any(|f: &AnonField| f.name == field_name) {
                        return Err(format!(
                            "Error: field {} in table {} is defined more than once in config file at line {}",
                            field_name, table_name, line
                        ));
                    }
                    self.expect_eq()?;
                    let field = self.parse_field_action(&field_name, table_name)?;
                    fields.push(field);
                }
                _ => {
                    return Err(self.error(&format!(
                        "expected field name or '}}', got {}",
                        tok
                    )))
                }
            }
        }

        Ok(fields)
    }

    fn parse_field_action(
        &mut self,
        field_name: &str,
        table_name: &str,
    ) -> Result<AnonField, String> {
        let tok = self.lexer.next_token()?;
        let mut infos = AnonBase::default();
        let mut json_list = Vec::new();

        match tok {
            Token::FixedNull => {
                infos.anon_type = AnonType::FixedNull;
            }
            Token::Fixed => {
                infos.anon_type = AnonType::Fixed;
                infos.fixed_value = self.expect_string()?;
            }
            Token::FixedQuoted => {
                infos.anon_type = AnonType::FixedQuoted;
                infos.fixed_value = self.expect_string()?;
            }
            Token::FixedUnquoted => {
                infos.anon_type = AnonType::FixedUnquoted;
                infos.fixed_value = self.expect_string()?;
            }
            Token::TextHash => {
                infos.anon_type = AnonType::TextHash;
                infos.len = self.expect_length()?;
            }
            Token::EmailHash => {
                infos.anon_type = AnonType::EmailHash;
                infos.domain = self.expect_string()?;
                infos.len = self.expect_length()?;
                let domain_len = infos.domain.len() as u16;
                if infos.len + domain_len + 1 > MAX_LEN {
                    return Err(self.error("Requested length is too long"));
                }
            }
            Token::IntHash => {
                infos.anon_type = AnonType::IntHash;
                infos.len = self.expect_length()?;
            }
            Token::Substring => {
                infos.anon_type = AnonType::Substring;
                infos.len = self.expect_length()?;
            }
            Token::Key => {
                infos.anon_type = AnonType::Key;
            }
            Token::AppendKey => {
                infos.anon_type = AnonType::AppendKey;
                infos.fixed_value = self.expect_string()?;
            }
            Token::PrependKey => {
                infos.anon_type = AnonType::PrependKey;
                infos.fixed_value = self.expect_string()?;
            }
            Token::AppendIndex => {
                infos.anon_type = AnonType::AppendIndex;
                infos.fixed_value = self.expect_string()?;
            }
            Token::PrependIndex => {
                infos.anon_type = AnonType::PrependIndex;
                infos.fixed_value = self.expect_string()?;
            }
            Token::PyDef => {
                infos.anon_type = AnonType::Py;
                infos.pydef = self.expect_string()?;
            }
            Token::Json => {
                infos.anon_type = AnonType::Json;
                json_list = self.parse_json_block(field_name, table_name)?;
            }
            _ => {
                return Err(self.error(&format!(
                    "expected anonymization type, got {}",
                    tok
                )))
            }
        }

        // Check for optional "separated by" clause
        if matches!(
            infos.anon_type,
            AnonType::FixedNull
                | AnonType::Fixed
                | AnonType::FixedQuoted
                | AnonType::FixedUnquoted
                | AnonType::TextHash
                | AnonType::EmailHash
                | AnonType::IntHash
                | AnonType::Substring
        ) {
            let peek = self.lexer.peek_token()?;
            if peek == Token::SeparatedBy {
                self.lexer.next_token()?; // consume
                let sep_str = self.expect_string()?;
                if sep_str.is_empty() {
                    return Err(self.error("separator string is empty"));
                }
                if sep_str.len() > 1 {
                    eprintln!("Warning: separator is only one char, keeping first char");
                }
                infos.separator = Some(sep_str.chars().next().unwrap());
            }
        }

        Ok(AnonField {
            name: field_name.to_string(),
            pos: -1,
            quoted: false,
            infos,
            json: json_list,
        })
    }

    fn parse_json_block(
        &mut self,
        field_name: &str,
        table_name: &str,
    ) -> Result<Vec<AnonJson>, String> {
        self.expect_lbrace()?;
        let mut json_entries = Vec::new();

        loop {
            let tok = self.lexer.next_token()?;
            match tok {
                Token::RBrace => break,
                Token::Path => {
                    let raw_path = self.expect_string()?;
                    let line = self.lexer.line;
                    // Add leading dot if not present
                    let filter = if !raw_path.starts_with('.') && !raw_path.starts_with('[') {
                        format!(".{}", raw_path)
                    } else {
                        raw_path.clone()
                    };

                    // Validate JSON path
                    if !is_valid_json_path(&filter) {
                        eprintln!("Warning: Invalid json path '{}', ignoring it", filter);
                        // Skip: = jsonaction
                        self.expect_eq()?;
                        self.skip_json_action()?;
                        continue;
                    }

                    // Check duplicate
                    if json_entries.iter().any(|j: &AnonJson| j.filter == filter) {
                        return Err(format!(
                            "Error: JSON path '{}' in field {} of table {} is defined more than once in config file at line {}",
                            filter, field_name, table_name, line
                        ));
                    }

                    self.expect_eq()?;
                    let json_infos = self.parse_json_action()?;

                    json_entries.push(AnonJson {
                        filter,
                        infos: json_infos,
                    });
                }
                _ => {
                    return Err(self.error(&format!("expected 'path' or '}}', got {}", tok)))
                }
            }
        }

        Ok(json_entries)
    }

    fn parse_json_action(&mut self) -> Result<AnonBase, String> {
        let tok = self.lexer.next_token()?;
        let mut infos = AnonBase::default();

        match tok {
            Token::Fixed => {
                infos.anon_type = AnonType::Fixed;
                infos.fixed_value = self.expect_string()?;
            }
            Token::TextHash => {
                infos.anon_type = AnonType::TextHash;
                infos.len = self.expect_length()?;
            }
            Token::EmailHash => {
                infos.anon_type = AnonType::EmailHash;
                infos.domain = self.expect_string()?;
                infos.len = self.expect_length()?;
                let domain_len = infos.domain.len() as u16;
                if infos.len + domain_len + 1 > MAX_LEN {
                    return Err(self.error("Requested length is too long"));
                }
            }
            Token::IntHash => {
                infos.anon_type = AnonType::IntHash;
                infos.len = self.expect_length()?;
            }
            Token::PyDef => {
                infos.anon_type = AnonType::Py;
                infos.pydef = self.expect_string()?;
            }
            _ => {
                return Err(self.error(&format!(
                    "expected JSON anonymization type (fixed/texthash/emailhash/inthash/pydef), got {}",
                    tok
                )))
            }
        }

        Ok(infos)
    }

    /// Skip a JSON action (used when the path is invalid and we want to skip it)
    fn skip_json_action(&mut self) -> Result<(), String> {
        let tok = self.lexer.next_token()?;
        match tok {
            Token::Fixed => {
                self.expect_string()?;
            }
            Token::TextHash => {
                self.expect_length()?;
            }
            Token::EmailHash => {
                self.expect_string()?;
                self.expect_length()?;
            }
            Token::IntHash => {
                self.expect_length()?;
            }
            Token::PyDef => {
                self.expect_string()?;
            }
            _ => return Err(self.error(&format!("expected JSON anonymization type, got {}", tok))),
        }
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_minimal_config() {
        let input = r#"
            secret = 'mysecret'
            tables = {
                `t1` = truncate
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert_eq!(config.secret, "mysecret");
        assert_eq!(config.tables.len(), 1);
        assert_eq!(config.tables[0].name, "t1");
        assert_eq!(config.tables[0].action, TableAction::Truncate);
    }

    #[test]
    fn test_stats_yes_no() {
        let input = "stats = 'yes'";
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert!(config.stats);

        let input = "stats = 'no'";
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert!(!config.stats);
    }

    #[test]
    fn test_field_types() {
        let input = r#"
            secret = 'test'
            tables = {
                `t` = {
                    `f1` = fixed null
                    `f2` = fixed 'value'
                    `f3` = fixed quoted 'value'
                    `f4` = fixed unquoted 'value'
                    `f5` = texthash 10
                    `f6` = emailhash 'example.com' 15
                    `f7` = inthash 5
                    `f8` = key
                    `f9` = appendkey 'prefix'
                    `f10` = prependkey 'suffix'
                    `f11` = substring 8
                    `f12` = appendindex 'idx'
                    `f13` = prependindex 'idx'
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        let fields = &config.tables[0].fields;
        assert_eq!(fields.len(), 13);
        assert_eq!(fields[0].infos.anon_type, AnonType::FixedNull);
        assert_eq!(fields[1].infos.anon_type, AnonType::Fixed);
        assert_eq!(fields[1].infos.fixed_value, "value");
        assert_eq!(fields[2].infos.anon_type, AnonType::FixedQuoted);
        assert_eq!(fields[3].infos.anon_type, AnonType::FixedUnquoted);
        assert_eq!(fields[4].infos.anon_type, AnonType::TextHash);
        assert_eq!(fields[4].infos.len, 10);
        assert_eq!(fields[5].infos.anon_type, AnonType::EmailHash);
        assert_eq!(fields[5].infos.domain, "example.com");
        assert_eq!(fields[5].infos.len, 15);
        assert_eq!(fields[6].infos.anon_type, AnonType::IntHash);
        assert_eq!(fields[7].infos.anon_type, AnonType::Key);
        assert_eq!(fields[8].infos.anon_type, AnonType::AppendKey);
        assert_eq!(fields[9].infos.anon_type, AnonType::PrependKey);
        assert_eq!(fields[10].infos.anon_type, AnonType::Substring);
        assert_eq!(fields[11].infos.anon_type, AnonType::AppendIndex);
        assert_eq!(fields[12].infos.anon_type, AnonType::PrependIndex);
    }

    #[test]
    fn test_separated_by() {
        let input = r#"
            secret = 'test'
            tables = {
                `t` = {
                    `emails` = emailhash 'example.com' 10 separated by ','
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        let field = &config.tables[0].fields[0];
        assert_eq!(field.infos.separator, Some(','));
    }

    #[test]
    fn test_json_field() {
        let input = r#"
            secret = 'test'
            tables = {
                `t` = {
                    `data` = json {
                        path 'name' = texthash 5
                        path 'email' = emailhash 'example.com' 10
                    }
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        let field = &config.tables[0].fields[0];
        assert_eq!(field.infos.anon_type, AnonType::Json);
        assert_eq!(field.json.len(), 2);
        assert_eq!(field.json[0].filter, ".name");
        assert_eq!(field.json[1].filter, ".email");
    }

    #[test]
    fn test_regex_table() {
        let input = r#"
            secret = 'test'
            tables = {
                regex `test_.*` = {
                    `data` = texthash 10
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert!(config.tables[0].regex.is_some());
        assert_eq!(config.tables[0].name, "test_.*");
    }

    #[test]
    fn test_duplicate_table_error() {
        let input = r#"
            tables = {
                `t1` = truncate
                `t1` = truncate
            }
        "#;
        let mut parser = Parser::new(input);
        let err = parser.parse().unwrap_err();
        assert!(err.contains("defined more than once"));
    }

    #[test]
    fn test_duplicate_field_error() {
        let input = r#"
            tables = {
                `t1` = {
                    `f1` = key
                    `f1` = key
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let err = parser.parse().unwrap_err();
        assert!(err.contains("defined more than once"));
    }

    #[test]
    fn test_duplicate_json_path_error() {
        let input = r#"
            tables = {
                `t1` = {
                    `f1` = json {
                        path 'name' = texthash 5
                        path 'name' = texthash 5
                    }
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let err = parser.parse().unwrap_err();
        assert!(err.contains("defined more than once"));
    }

    #[test]
    fn test_emailhash_length_validation() {
        let input = r#"
            tables = {
                `t` = {
                    `f` = emailhash 'verylongdomain.example.com' 10
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let err = parser.parse().unwrap_err();
        assert!(err.contains("too long"));
    }

    #[test]
    fn test_pydef() {
        let input = r#"
            pypath = './tests'
            pyscript = 'test_module'
            tables = {
                `t` = {
                    `f` = pydef 'my_func'
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert_eq!(config.pypath, "./tests");
        assert_eq!(config.pyscript, "test_module");
        assert_eq!(config.tables[0].fields[0].infos.anon_type, AnonType::Py);
        assert_eq!(config.tables[0].fields[0].infos.pydef, "my_func");
    }

    #[test]
    fn test_empty_fixed_string() {
        let input = r#"
            tables = {
                `t` = {
                    `f` = fixed ''
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert_eq!(config.tables[0].fields[0].infos.fixed_value, "");
    }

    #[test]
    fn test_json_path_with_brackets() {
        let input = r#"
            tables = {
                `t` = {
                    `f` = json {
                        path 'items[]' = texthash 5
                        path 'nested[][]' = texthash 5
                        path '[]' = texthash 5
                    }
                }
            }
        "#;
        let mut parser = Parser::new(input);
        let config = parser.parse().unwrap();
        assert_eq!(config.tables[0].fields[0].json[0].filter, ".items[]");
        assert_eq!(config.tables[0].fields[0].json[1].filter, ".nested[][]");
        assert_eq!(config.tables[0].fields[0].json[2].filter, "[]");
    }
}
