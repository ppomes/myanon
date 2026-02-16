use myanon::config::{AnonType, Parser, TableAction};
use std::fs;
use std::path::Path;

fn parse_file(name: &str) -> myanon::config::Config {
    let path = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("tests")
        .join(name);
    let input = fs::read_to_string(&path).unwrap_or_else(|e| panic!("Cannot read {}: {}", path.display(), e));
    let mut parser = Parser::new(&input);
    parser
        .parse()
        .unwrap_or_else(|e| panic!("Failed to parse {}: {}", name, e))
}

#[test]
fn test_all_configs_parse() {
    let configs = [
        "test1.conf",
        "test1-insert-ignore.conf",
        "test2.conf",
        "null-example.conf",
        "appendkey.conf",
        "prependkey.conf",
        "appendindex.conf",
        "prependindex.conf",
        "issue29.conf",
        "test_substring.conf",
        "test_regex.conf",
        "complex.conf",
        "test_python.conf",
        "faker_test.conf",
        "test_large_python.conf",
        "test_large_python_2.conf",
    ];
    for name in &configs {
        parse_file(name);
    }
}

#[test]
fn test_test1_details() {
    let config = parse_file("test1.conf");
    assert_eq!(config.secret, "lapin");
    assert!(!config.stats);
    assert_eq!(config.tables.len(), 6);

    // lottypes: 9 fields
    assert_eq!(config.tables[0].name, "lottypes");
    assert_eq!(config.tables[0].action, TableAction::Anon);
    assert_eq!(config.tables[0].fields.len(), 9);
    assert_eq!(config.tables[0].fields[0].infos.anon_type, AnonType::IntHash);
    assert_eq!(config.tables[0].fields[0].infos.len, 2);
    assert_eq!(config.tables[0].fields[5].infos.anon_type, AnonType::FixedNull);

    // truncate table
    assert_eq!(config.tables[1].name, "table to truncate");
    assert_eq!(config.tables[1].action, TableAction::Truncate);

    // emailhash
    assert_eq!(config.tables[2].fields[1].infos.anon_type, AnonType::EmailHash);
    assert_eq!(config.tables[2].fields[1].infos.domain, "example.com");
    assert_eq!(config.tables[2].fields[1].infos.len, 10);

    // fixed unquoted
    assert_eq!(config.tables[4].fields[0].infos.anon_type, AnonType::FixedUnquoted);
    assert_eq!(config.tables[4].fields[0].infos.fixed_value, "0x676f6f64627965");
}

#[test]
fn test_complex_json() {
    let config = parse_file("complex.conf");
    assert_eq!(config.tables[0].name, "points");

    // owner: json with 3 paths
    let owner = &config.tables[0].fields[1];
    assert_eq!(owner.infos.anon_type, AnonType::Json);
    assert_eq!(owner.json.len(), 3);
    assert_eq!(owner.json[0].filter, ".email");
    assert_eq!(owner.json[0].infos.anon_type, AnonType::EmailHash);
    assert_eq!(owner.json[1].filter, ".last_name");
    assert_eq!(owner.json[2].filter, ".first_name");

    // emails: separated by
    let emails = &config.tables[0].fields[2];
    assert_eq!(emails.infos.separator, Some(','));

    // history: json with array path
    let history = &config.tables[0].fields[3];
    assert_eq!(history.json[0].filter, ".email_changes[][]");

    // contacts: json with bare array path
    let contacts = &config.tables[0].fields[4];
    assert_eq!(contacts.json[0].filter, "[]");
}

#[test]
fn test_regex_table() {
    let config = parse_file("test_regex.conf");
    assert!(config.tables[0].regex.is_some());
    assert_eq!(config.tables[0].name, "(prod|test)players");
    let re = config.tables[0].regex.as_ref().unwrap();
    assert!(re.is_match("prodplayers"));
    assert!(re.is_match("testplayers"));
    assert!(!re.is_match("devplayers"));
}

#[test]
fn test_python_config() {
    let config = parse_file("test_python.conf");
    assert_eq!(config.pypath, "./tests");
    assert_eq!(config.pyscript, "test_python");
    assert_eq!(config.tables[0].fields[0].infos.anon_type, AnonType::Py);
    assert_eq!(config.tables[0].fields[0].infos.pydef, "pytest");
}

#[test]
fn test_duplicate_table_rejected() {
    let input = r#"
        tables = {
            `t1` = truncate
            `t1` = truncate
        }
    "#;
    let mut parser = Parser::new(input);
    let err = parser.parse().unwrap_err();
    assert!(err.contains("table t1 is defined more than once"));
}

#[test]
fn test_duplicate_field_rejected() {
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
    assert!(err.contains("field f1 in table t1 is defined more than once"));
}

#[test]
fn test_duplicate_json_path_rejected() {
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
    assert!(err.contains("JSON path '.name' in field f1 of table t1 is defined more than once"));
}

#[test]
fn test_emailhash_too_long() {
    let input = r#"
        tables = {
            `t` = {
                `f` = emailhash 'very-long-domain.example.com' 10
            }
        }
    "#;
    let mut parser = Parser::new(input);
    let err = parser.parse().unwrap_err();
    assert!(err.contains("too long"));
}
