use std::io::{BufRead, BufReader, Read, Write};

use crate::anonymize::{anonymize_token, remove_quote, AnonContext, AnonResult, QuoteMode};
use crate::config::{AnonType, Config, TableAction};
use crate::json;
#[cfg(feature = "python")]
use crate::python::PythonRunner;

const MYSQL_MAX_FIELD_PER_TABLE: usize = 4096;

#[derive(Debug, PartialEq, Clone, Copy)]
enum State {
    Initial,
    InTable,
    Truncate,
}

/// Field info captured during CREATE TABLE parsing
struct FieldInfo {
    name: String,
    quoted: bool,
}

pub struct DumpProcessor<'a> {
    config: &'a mut Config,
    state: State,
    current_table: String,
    current_table_config_idx: Option<usize>,
    fields: Vec<FieldInfo>,
    field_config_cache: Vec<Option<usize>>,
    tablekey: String,
    row_index: i32,
    bfirstinsert: bool,
    line_nb: usize,
    #[cfg(feature = "python")]
    python_runner: Option<PythonRunner>,
}

impl<'a> DumpProcessor<'a> {
    pub fn new(config: &'a mut Config) -> Result<Self, String> {
        #[cfg(feature = "python")]
        let python_runner = if !config.pyscript.is_empty() {
            Some(PythonRunner::new(
                &config.pypath,
                &config.pyscript,
                config.secret.clone(),
            )?)
        } else {
            None
        };

        Ok(DumpProcessor {
            config,
            state: State::Initial,
            current_table: String::new(),
            current_table_config_idx: None,
            fields: Vec::new(),
            field_config_cache: vec![None; MYSQL_MAX_FIELD_PER_TABLE],
            tablekey: String::new(),
            row_index: 0,
            bfirstinsert: true,
            line_nb: 1,
            #[cfg(feature = "python")]
            python_runner,
        })
    }

    pub fn process<R: Read, W: Write>(
        &mut self,
        reader: R,
        writer: &mut W,
    ) -> Result<(), String> {
        let mut reader = BufReader::with_capacity(65536, reader);
        let mut line_buf: Vec<u8> = Vec::with_capacity(8192);

        loop {
            line_buf.clear();
            let bytes_read = reader
                .read_until(b'\n', &mut line_buf)
                .map_err(|e| format!("Read error: {}", e))?;
            if bytes_read == 0 {
                break;
            }

            self.process_line(&line_buf, writer)?;
        }

        Ok(())
    }

    fn process_line<W: Write>(&mut self, line: &[u8], writer: &mut W) -> Result<(), String> {
        match self.state {
            State::Initial => self.process_initial(line, writer),
            State::InTable => self.process_in_table(line, writer),
            State::Truncate => self.process_truncate(line, writer),
        }
    }

    fn find_table_config(&self, table_name: &str) -> Option<usize> {
        for (i, table) in self.config.tables.iter().enumerate() {
            if let Some(ref regex) = table.regex {
                let with_backticks = format!("`{}`", table_name);
                if regex.is_match(&with_backticks) {
                    return Some(i);
                }
            } else if table.name == table_name {
                return Some(i);
            }
        }
        None
    }

    fn extract_table_name_bytes(line: &[u8]) -> Option<String> {
        let start = line.iter().position(|&b| b == b'`')?;
        let end = line[start + 1..].iter().position(|&b| b == b'`')?;
        String::from_utf8(line[start + 1..start + 1 + end].to_vec()).ok()
    }

    fn set_working_table(&mut self, line: &[u8]) {
        self.current_table = Self::extract_table_name_bytes(line).unwrap_or_default();
        self.current_table_config_idx = self.find_table_config(&self.current_table);
    }

    fn is_insert_replace_line(line: &[u8]) -> bool {
        line.starts_with(b"INSERT ") || line.starts_with(b"REPLACE ")
    }

    fn process_initial<W: Write>(&mut self, line: &[u8], writer: &mut W) -> Result<(), String> {
        if line.starts_with(b"CREATE TABLE `") {
            self.set_working_table(line);
            writer.write_all(line).map_err(|e| e.to_string())?;

            if let Some(idx) = self.current_table_config_idx {
                let action = self.config.tables[idx].action.clone();
                match action {
                    TableAction::Anon => {
                        self.state = State::InTable;
                        self.fields.clear();
                        self.bfirstinsert = true;
                        self.row_index = 0;
                        self.field_config_cache = vec![None; MYSQL_MAX_FIELD_PER_TABLE];
                    }
                    TableAction::Truncate => {
                        self.state = State::Truncate;
                    }
                }
            }
            self.count_newlines(line);
            return Ok(());
        }

        if Self::is_insert_replace_line(line) {
            if self.current_table_config_idx.is_some() {
                self.process_insert_line(line, writer)?;
                self.count_newlines(line);
                return Ok(());
            }
        }

        writer.write_all(line).map_err(|e| e.to_string())?;
        self.count_newlines(line);
        Ok(())
    }

    fn process_in_table<W: Write>(&mut self, line: &[u8], writer: &mut W) -> Result<(), String> {
        writer.write_all(line).map_err(|e| e.to_string())?;

        // Line may be binary, but keywords are ASCII. Use lossy conversion for matching.
        let line_str = String::from_utf8_lossy(line);
        let trimmed = line_str.trim_start();

        // Check for ENGINE line or ) ENGINE (end of CREATE TABLE)
        if trimmed.starts_with("ENGINE") || trimmed.starts_with(") ENGINE") {
            self.resolve_field_positions();
            self.state = State::Initial;
            self.count_newlines(line);
            return Ok(());
        }

        // Skip index/constraint lines
        if trimmed.starts_with("PRIMARY KEY")
            || trimmed.starts_with("UNIQUE KEY")
            || trimmed.starts_with("FULLTEXT KEY")
            || (trimmed.starts_with("KEY ") || trimmed.starts_with("KEY`"))
            || trimmed.starts_with("CONSTRAINT")
            || trimmed.starts_with("DELIMITER")
        {
            self.count_newlines(line);
            return Ok(());
        }

        // Try to parse a field definition: `fieldname` type...
        if trimmed.starts_with('`') {
            if let Some(end) = trimmed[1..].find('`') {
                let field_name = &trimmed[1..1 + end];
                let rest = &trimmed[2 + end..];
                let rest_trimmed = rest.trim_start();

                let quoted = Self::is_quoted_type(rest_trimmed);

                self.fields.push(FieldInfo {
                    name: field_name.to_string(),
                    quoted,
                });
            }
        }

        self.count_newlines(line);
        Ok(())
    }

    fn is_quoted_type(type_str: &str) -> bool {
        let lower = type_str.to_lowercase();
        // Check QTYPE patterns (ordered to avoid prefix conflicts)
        lower.starts_with("tinytext")
            || lower.starts_with("mediumtext")
            || lower.starts_with("longtext")
            || lower.starts_with("text")
            || lower.starts_with("enum")
            || lower.starts_with("char(")
            || lower.starts_with("varchar(")
            || lower.starts_with("tinyblob")
            || lower.starts_with("mediumblob")
            || lower.starts_with("longblob")
            || lower.starts_with("blob")
            || lower.starts_with("datetime")
            || lower.starts_with("date")
            || lower.starts_with("timestamp")
            || lower.starts_with("time")
            || lower.starts_with("json")
            || lower.starts_with("set")
    }

    fn resolve_field_positions(&mut self) {
        if let Some(table_idx) = self.current_table_config_idx {
            let table = &mut self.config.tables[table_idx];
            if table.action != TableAction::Anon {
                return;
            }
            for (pos, field_info) in self.fields.iter().enumerate() {
                for config_field in table.fields.iter_mut() {
                    if config_field.name == field_info.name {
                        config_field.pos = pos as i32;
                        config_field.quoted = field_info.quoted;
                        break;
                    }
                }
            }
        }
    }

    fn process_truncate<W: Write>(&mut self, line: &[u8], writer: &mut W) -> Result<(), String> {
        if line.starts_with(b"CREATE TABLE `") {
            self.set_working_table(line);
            writer.write_all(line).map_err(|e| e.to_string())?;

            if let Some(idx) = self.current_table_config_idx {
                let action = self.config.tables[idx].action.clone();
                match action {
                    TableAction::Anon => {
                        self.state = State::InTable;
                        self.fields.clear();
                        self.bfirstinsert = true;
                        self.row_index = 0;
                        self.field_config_cache = vec![None; MYSQL_MAX_FIELD_PER_TABLE];
                    }
                    TableAction::Truncate => {
                        self.state = State::Truncate;
                    }
                }
            } else {
                self.state = State::Initial;
            }
            self.count_newlines(line);
            return Ok(());
        }

        if Self::is_insert_replace_line(line) {
            // Suppress INSERT/REPLACE lines in truncate mode
            // But output the trailing newline (matching C behavior where \n after ; is DUPOUT'd)
            if line.last() == Some(&b'\n') {
                writer.write_all(b"\n").map_err(|e| e.to_string())?;
            }
            self.count_newlines(line);
            return Ok(());
        }

        // Other lines pass through
        writer.write_all(line).map_err(|e| e.to_string())?;
        self.count_newlines(line);
        Ok(())
    }

    fn count_newlines(&mut self, s: &[u8]) {
        self.line_nb += s.iter().filter(|&&b| b == b'\n').count();
    }

    /// Find byte subsequence in a byte slice.
    fn find_bytes(haystack: &[u8], needle: &[u8]) -> Option<usize> {
        haystack
            .windows(needle.len())
            .position(|w| w == needle)
    }

    /// Process an INSERT/REPLACE line with value anonymization.
    fn process_insert_line<W: Write>(&mut self, line: &[u8], writer: &mut W) -> Result<(), String> {
        let table_idx = match self.current_table_config_idx {
            Some(idx) => idx,
            None => {
                writer.write_all(line).map_err(|e| e.to_string())?;
                return Ok(());
            }
        };

        // Find the " VALUES " keyword
        let values_pos = match Self::find_bytes(line, b" VALUES ") {
            Some(pos) => pos,
            None => {
                writer.write_all(line).map_err(|e| e.to_string())?;
                return Ok(());
            }
        };

        // Write prefix including " VALUES "
        let prefix_end = values_pos + 8;
        writer
            .write_all(&line[..prefix_end])
            .map_err(|e| e.to_string())?;

        // Parse values portion
        self.parse_values(&line[prefix_end..], table_idx, writer)?;

        Ok(())
    }

    fn parse_values<W: Write>(
        &mut self,
        bytes: &[u8],
        table_idx: usize,
        writer: &mut W,
    ) -> Result<(), String> {
        let len = bytes.len();
        let mut pos = 0;
        let mut current_field_pos: usize = 0;
        let mut in_tuple = false;

        while pos < len {
            let b = bytes[pos];

            match b {
                b'(' => {
                    writer.write_all(b"(").map_err(|e| e.to_string())?;
                    pos += 1;
                    current_field_pos = 0;
                    self.row_index += 1;
                    self.tablekey.clear();
                    in_tuple = true;
                }
                b')' => {
                    writer.write_all(b")").map_err(|e| e.to_string())?;
                    pos += 1;
                    self.bfirstinsert = false;
                    in_tuple = false;
                }
                b',' => {
                    writer.write_all(b",").map_err(|e| e.to_string())?;
                    pos += 1;
                    if in_tuple {
                        // Comma between fields in a tuple
                        current_field_pos += 1;
                    }
                    // If not in tuple, comma between tuples
                }
                b';' => {
                    writer.write_all(b";").map_err(|e| e.to_string())?;
                    pos += 1;
                }
                b'\n' => {
                    writer.write_all(b"\n").map_err(|e| e.to_string())?;
                    pos += 1;
                    self.line_nb += 1;
                }
                b' ' => {
                    writer.write_all(b" ").map_err(|e| e.to_string())?;
                    pos += 1;
                }
                _ if in_tuple => {
                    // Parse a value token
                    let (token_type, end_pos) = self.scan_value(bytes, pos)?;
                    let raw = &bytes[pos..end_pos];
                    self.handle_value(
                        &token_type,
                        raw,
                        current_field_pos,
                        table_idx,
                        writer,
                    )?;
                    pos = end_pos;
                }
                _ => {
                    // Outside of a tuple, pass through
                    writer.write_all(&[b]).map_err(|e| e.to_string())?;
                    pos += 1;
                }
            }
        }

        Ok(())
    }

    fn scan_value(&self, bytes: &[u8], pos: usize) -> Result<(ValueToken, usize), String> {
        let len = bytes.len();

        // NULL
        if pos + 4 <= len && &bytes[pos..pos + 4] == b"NULL" {
            if pos + 4 >= len || !bytes[pos + 4].is_ascii_alphanumeric() {
                return Ok((ValueToken::Null, pos + 4));
            }
        }

        // Hex binary: 0x[0-9a-fA-F]+
        if pos + 2 < len && bytes[pos] == b'0' && bytes[pos + 1] == b'x' {
            let mut end = pos + 2;
            while end < len && bytes[end].is_ascii_hexdigit() {
                end += 1;
            }
            if end > pos + 2 {
                return Ok((ValueToken::Raw, end));
            }
        }

        // _binary 'string' — treated as a quoted value (the whole token including
        // _binary prefix is passed to anonymize_token, matching C behavior)
        if pos + 8 <= len && &bytes[pos..pos + 8] == b"_binary " {
            if pos + 8 < len && bytes[pos + 8] == b'\'' {
                let end = self.scan_sql_string(bytes, pos + 8)?;
                return Ok((ValueToken::Quoted, end));
            }
        }

        // Single-quoted string
        if bytes[pos] == b'\'' {
            let end = self.scan_sql_string(bytes, pos)?;
            return Ok((ValueToken::Quoted, end));
        }

        // Numeric value: [0-9\-\.eE+]+
        if bytes[pos].is_ascii_digit()
            || bytes[pos] == b'-'
            || bytes[pos] == b'.'
        {
            let mut end = pos;
            while end < len {
                let c = bytes[end];
                if c.is_ascii_digit()
                    || c == b'-'
                    || c == b'.'
                    || c == b'e'
                    || c == b'E'
                    || c == b'+'
                {
                    end += 1;
                } else {
                    break;
                }
            }
            if end > pos {
                return Ok((ValueToken::Unquoted, end));
            }
        }

        Err(format!(
            "Unexpected character '{}' at line {}",
            bytes[pos] as char, self.line_nb
        ))
    }

    fn scan_sql_string(&self, bytes: &[u8], pos: usize) -> Result<usize, String> {
        let mut i = pos + 1; // skip opening quote
        let len = bytes.len();
        while i < len {
            if bytes[i] == b'\\' && i + 1 < len {
                i += 2;
            } else if bytes[i] == b'\'' {
                return Ok(i + 1);
            } else {
                i += 1;
            }
        }
        Err(format!("Unterminated string at line {}", self.line_nb))
    }

    fn handle_value<W: Write>(
        &mut self,
        token_type: &ValueToken,
        raw: &[u8],
        current_field_pos: usize,
        table_idx: usize,
        writer: &mut W,
    ) -> Result<(), String> {
        // Find field config
        let field_idx = if self.bfirstinsert {
            let table = &self.config.tables[table_idx];
            let mut found_idx = None;
            for (fi, config_field) in table.fields.iter().enumerate() {
                if config_field.pos == current_field_pos as i32 {
                    found_idx = Some(fi);
                    break;
                }
            }
            if let Some(fi) = found_idx {
                if current_field_pos < MYSQL_MAX_FIELD_PER_TABLE {
                    self.field_config_cache[current_field_pos] = Some(fi);
                }
            }
            found_idx
        } else if current_field_pos < self.field_config_cache.len() {
            self.field_config_cache[current_field_pos]
        } else {
            None
        };

        // No config for this field - output raw
        let field_idx = match field_idx {
            Some(idx) => idx,
            None => {
                writer.write_all(raw).map_err(|e| e.to_string())?;
                return Ok(());
            }
        };

        // NULL values remain NULL
        if *token_type == ValueToken::Null {
            writer.write_all(b"NULL").map_err(|e| e.to_string())?;
            return Ok(());
        }

        // Increment hit counter
        self.config.tables[table_idx].fields[field_idx].infos.nbhits += 1;

        let field_quoted = self.config.tables[table_idx].fields[field_idx].quoted;
        let anon_type = self.config.tables[table_idx].fields[field_idx]
            .infos
            .anon_type
            .clone();

        // JSON anonymization
        if anon_type == AnonType::Json {
            let handled = self.handle_json_anonymization(raw, table_idx, field_idx, writer)?;
            if !handled {
                writer.write_all(raw).map_err(|e| e.to_string())?;
            }
            return Ok(());
        }

        // Python anonymization
        if anon_type == AnonType::Py {
            let res = self.handle_py_anonymization(raw, field_quoted, table_idx, field_idx);
            let out_quoted = match res.quoting {
                QuoteMode::ForceTrue => true,
                QuoteMode::ForceFalse => false,
                QuoteMode::AsInput => field_quoted,
            };
            self.write_quoted_output(&res.data, out_quoted, writer)?;
            return Ok(());
        }

        // Separated values
        let has_separator = self.config.tables[table_idx].fields[field_idx]
            .infos
            .separator
            .is_some();

        if has_separator {
            self.handle_separated_values(raw, table_idx, field_idx, field_quoted, writer)?;
            return Ok(());
        }

        // Normal anonymization
        let secret = self.config.secret.as_bytes().to_vec();
        let mut ctx = AnonContext {
            tablekey: self.tablekey.clone(),
            rowindex: self.row_index,
            bfirstinsert: self.bfirstinsert,
            tablename: self.current_table.clone(),
        };

        let config = &self.config.tables[table_idx].fields[field_idx].infos;
        let res = anonymize_token(field_quoted, config, raw, &secret, Some(&mut ctx));

        self.tablekey = ctx.tablekey;

        let out_quoted = match res.quoting {
            QuoteMode::ForceTrue => true,
            QuoteMode::ForceFalse => false,
            QuoteMode::AsInput => field_quoted,
        };

        self.write_quoted_output(&res.data, out_quoted, writer)?;
        Ok(())
    }

    fn handle_json_anonymization<W: Write>(
        &mut self,
        raw: &[u8],
        table_idx: usize,
        field_idx: usize,
        writer: &mut W,
    ) -> Result<bool, String> {
        // Remove quotes
        let unquoted = String::from_utf8(remove_quote(raw)).unwrap_or_default();

        // Remove JSON backslash escaping
        let unbackslashed = json::remove_json_backslash(&unquoted);

        // Parse JSON
        let mut parsed = match json::json_parse_string(&unbackslashed) {
            Some(v) => v,
            None => {
                let field_name = &self.config.tables[table_idx].fields[field_idx].name;
                eprintln!(
                    "WARNING! Table/field {}: Unable to parse json field '{}' at line {}, skip anonymization",
                    field_name, unbackslashed, self.line_nb
                );
                return Ok(false);
            }
        };

        let secret = self.config.secret.clone();

        // Collect JSON rules
        let json_rules: Vec<(String, crate::config::AnonBase)> = self.config.tables[table_idx]
            .fields[field_idx]
            .json
            .iter()
            .map(|j| (j.filter.clone(), j.infos.clone()))
            .collect();

        for (i, (filter, rule_config)) in json_rules.iter().enumerate() {
            if json::json_path_has_wildcards(filter) {
                json::json_anonymize_path(&mut parsed, filter, rule_config, secret.as_bytes());
            } else {
                let current_value = json::json_get_string_at_path(&parsed, filter);
                if current_value.is_none() {
                    continue;
                }
                let current_value = current_value.unwrap();

                let new_value = if rule_config.anon_type == AnonType::Fixed {
                    rule_config.fixed_value.clone()
                } else {
                    let res = anonymize_token(
                        false,
                        rule_config,
                        current_value.as_bytes(),
                        secret.as_bytes(),
                        None,
                    );
                    String::from_utf8(res.data).unwrap_or_default()
                };

                json::json_replace_value_at_path(&mut parsed, filter, &new_value);
            }

            // Increment hit counter for this JSON path
            self.config.tables[table_idx].fields[field_idx].json[i].infos.nbhits += 1;
        }

        // Serialize back to JSON
        let result_str = json::json_to_string(&parsed);
        let backslashed = json::add_json_backslash(&result_str);

        self.write_quoted_output(backslashed.as_bytes(), true, writer)?;

        Ok(true)
    }

    fn handle_py_anonymization(
        &self,
        raw: &[u8],
        field_quoted: bool,
        table_idx: usize,
        field_idx: usize,
    ) -> AnonResult {
        // Strip quotes like anonymize_token does
        let worktoken = if field_quoted {
            remove_quote(raw)
        } else {
            raw.to_vec()
        };
        let value_str = String::from_utf8_lossy(&worktoken);
        let pydef = &self.config.tables[table_idx].fields[field_idx].infos.pydef;

        #[cfg(feature = "python")]
        {
            if let Some(ref runner) = self.python_runner {
                match runner.call(pydef, &value_str) {
                    Ok(result) => {
                        return AnonResult {
                            data: result.into_bytes(),
                            quoting: QuoteMode::AsInput,
                        };
                    }
                    Err(e) => {
                        eprintln!("{}", e);
                    }
                }
            }
        }

        #[cfg(not(feature = "python"))]
        {
            let _ = (pydef, &value_str);
            eprintln!("Python support not compiled in, cannot use pydef");
        }

        AnonResult {
            data: Vec::new(),
            quoting: QuoteMode::AsInput,
        }
    }

    fn handle_separated_values<W: Write>(
        &mut self,
        raw: &[u8],
        table_idx: usize,
        field_idx: usize,
        field_quoted: bool,
        writer: &mut W,
    ) -> Result<(), String> {
        let separator = self.config.tables[table_idx].fields[field_idx]
            .infos
            .separator
            .unwrap();

        let worktext = if field_quoted {
            String::from_utf8(remove_quote(raw)).unwrap_or_default()
        } else {
            String::from_utf8_lossy(raw).to_string()
        };

        let parts: Vec<&str> = worktext.split(separator).collect();

        if parts.is_empty() {
            writer.write_all(raw).map_err(|e| e.to_string())?;
            return Ok(());
        }

        let secret = self.config.secret.as_bytes().to_vec();

        writer.write_all(b"'").map_err(|e| e.to_string())?;

        for (i, part) in parts.iter().enumerate() {
            if i > 0 {
                writer
                    .write_all(&[separator as u8])
                    .map_err(|e| e.to_string())?;
            }

            let mut ctx = AnonContext {
                tablekey: self.tablekey.clone(),
                rowindex: self.row_index,
                bfirstinsert: self.bfirstinsert,
                tablename: self.current_table.clone(),
            };

            let config = &self.config.tables[table_idx].fields[field_idx].infos;
            let res = anonymize_token(false, config, part.as_bytes(), &secret, Some(&mut ctx));
            self.tablekey = ctx.tablekey;

            let out_quoted = match res.quoting {
                QuoteMode::ForceTrue => true,
                QuoteMode::ForceFalse => false,
                QuoteMode::AsInput => false,
            };

            self.write_quoted_output(&res.data, out_quoted, writer)?;
        }

        writer.write_all(b"'").map_err(|e| e.to_string())?;

        Ok(())
    }

    fn write_quoted_output<W: Write>(
        &self,
        data: &[u8],
        quoted: bool,
        writer: &mut W,
    ) -> Result<(), String> {
        if quoted {
            writer.write_all(b"'").map_err(|e| e.to_string())?;
            writer.write_all(data).map_err(|e| e.to_string())?;
            writer.write_all(b"'").map_err(|e| e.to_string())?;
        } else {
            writer.write_all(data).map_err(|e| e.to_string())?;
        }
        Ok(())
    }
}

#[derive(Debug, PartialEq)]
enum ValueToken {
    Null,
    Raw,
    Quoted,
    Unquoted,
}
