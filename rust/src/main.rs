use std::env;
use std::fs;
use std::process;

use myanon::config::{AnonType, Parser, TableAction};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() != 2 {
        eprintln!("Usage: {} <config-file>", args[0]);
        process::exit(1);
    }

    let filename = &args[1];
    let input = match fs::read_to_string(filename) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("Error reading {}: {}", filename, e);
            process::exit(1);
        }
    };

    let mut parser = Parser::new(&input);
    let config = match parser.parse() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{}", e);
            process::exit(1);
        }
    };

    // Print parsed config summary
    if !config.secret.is_empty() {
        println!("Secret: (set, {} chars)", config.secret.len());
    }
    println!("Stats: {}", if config.stats { "yes" } else { "no" });
    if !config.pypath.is_empty() {
        println!("PyPath: {}", config.pypath);
    }
    if !config.pyscript.is_empty() {
        println!("PyScript: {}", config.pyscript);
    }
    println!("Tables: {}", config.tables.len());

    for table in &config.tables {
        let regex_tag = if table.regex.is_some() { " (regex)" } else { "" };
        match table.action {
            TableAction::Truncate => {
                println!("  {} = truncate{}", table.name, regex_tag);
            }
            TableAction::Anon => {
                println!("  {}{} = {{ {} fields }}", table.name, regex_tag, table.fields.len());
                for field in &table.fields {
                    let type_desc = match &field.infos.anon_type {
                        AnonType::FixedNull => "fixed null".to_string(),
                        AnonType::Fixed => format!("fixed '{}'", field.infos.fixed_value),
                        AnonType::FixedQuoted => {
                            format!("fixed quoted '{}'", field.infos.fixed_value)
                        }
                        AnonType::FixedUnquoted => {
                            format!("fixed unquoted '{}'", field.infos.fixed_value)
                        }
                        AnonType::TextHash => format!("texthash {}", field.infos.len),
                        AnonType::EmailHash => {
                            format!("emailhash '{}' {}", field.infos.domain, field.infos.len)
                        }
                        AnonType::IntHash => format!("inthash {}", field.infos.len),
                        AnonType::Key => "key".to_string(),
                        AnonType::AppendKey => {
                            format!("appendkey '{}'", field.infos.fixed_value)
                        }
                        AnonType::PrependKey => {
                            format!("prependkey '{}'", field.infos.fixed_value)
                        }
                        AnonType::AppendIndex => {
                            format!("appendindex '{}'", field.infos.fixed_value)
                        }
                        AnonType::PrependIndex => {
                            format!("prependindex '{}'", field.infos.fixed_value)
                        }
                        AnonType::Substring => format!("substring {}", field.infos.len),
                        AnonType::Json => format!("json {{ {} paths }}", field.json.len()),
                        AnonType::Py => format!("pydef '{}'", field.infos.pydef),
                    };
                    let sep = match field.infos.separator {
                        Some(c) => format!(" separated by '{}'", c),
                        None => String::new(),
                    };
                    println!("    {} = {}{}", field.name, type_desc, sep);
                    for j in &field.json {
                        let jtype = match &j.infos.anon_type {
                            AnonType::Fixed => format!("fixed '{}'", j.infos.fixed_value),
                            AnonType::TextHash => format!("texthash {}", j.infos.len),
                            AnonType::EmailHash => {
                                format!("emailhash '{}' {}", j.infos.domain, j.infos.len)
                            }
                            AnonType::IntHash => format!("inthash {}", j.infos.len),
                            AnonType::Py => format!("pydef '{}'", j.infos.pydef),
                            other => format!("{:?}", other),
                        };
                        println!("      path '{}' = {}", j.filter, jtype);
                    }
                }
            }
        }
    }
}
