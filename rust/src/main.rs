use std::env;
use std::fs;
use std::io::{self, BufWriter, Write};
use std::process;
use std::time::Instant;

use myanon::config::Parser;
use myanon::dump::DumpProcessor;

const VERSION: &str = "0.8.2-dev";
const PACKAGE_NAME: &str = "myanon";
const STDOUT_BUFFER_SIZE: usize = 1048576;

fn main() {
    let args: Vec<String> = env::args().collect();

    let mut config_file: Option<String> = None;
    let mut debug = false;

    let mut i = 1;
    while i < args.len() {
        match args[i].as_str() {
            "-f" => {
                i += 1;
                if i >= args.len() {
                    eprintln!("Option -f requires a config file as argument.");
                    process::exit(1);
                }
                config_file = Some(args[i].clone());
            }
            "-d" => {
                debug = true;
            }
            "-v" | "--version" => {
                println!("{} {}", PACKAGE_NAME, VERSION);
                process::exit(0);
            }
            "-h" | "--help" => {
                println!("Usage: {} -f config_file [-d]", args[0]);
                println!("\nOptions:");
                println!("  -f <file>      Configuration file");
                println!("  -d             Debug mode");
                println!("  -v, --version  Show version");
                println!("  -h, --help     Show this help");
                process::exit(0);
            }
            _ => {
                eprintln!("Unknown option: {}", args[i]);
                process::exit(1);
            }
        }
        i += 1;
    }

    let config_file = match config_file {
        Some(f) => f,
        None => {
            eprintln!("Usage: {} -f config_file [-d]", args[0]);
            eprintln!("\nOptions:");
            eprintln!("  -f <file>      Configuration file");
            eprintln!("  -d             Debug mode");
            eprintln!("  -v, --version  Show version");
            eprintln!("  -h, --help     Show this help");
            process::exit(1);
        }
    };

    let ts_beg = Instant::now();

    // Load config
    let input = match fs::read_to_string(&config_file) {
        Ok(s) => s,
        Err(_) => {
            eprintln!("Unable to load config {}", config_file);
            process::exit(1);
        }
    };

    let mut parser = Parser::new(&input);
    let mut config = match parser.parse() {
        Ok(c) => c,
        Err(e) => {
            eprintln!("{}", e);
            process::exit(1);
        }
    };

    // Process dump
    let stdin = io::stdin();
    let stdout = io::stdout();

    let result = if debug {
        let mut writer = stdout.lock();
        let mut processor = match DumpProcessor::new(&mut config) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("{}", e);
                process::exit(1);
            }
        };
        processor.process(stdin.lock(), &mut writer)
    } else {
        let mut writer = BufWriter::with_capacity(STDOUT_BUFFER_SIZE, stdout.lock());
        let mut processor = match DumpProcessor::new(&mut config) {
            Ok(p) => p,
            Err(e) => {
                eprintln!("{}", e);
                process::exit(1);
            }
        };
        let result = processor.process(stdin.lock(), &mut writer);
        writer.flush().ok();
        result
    };

    if let Err(e) = result {
        let stdout = io::stdout();
        let _ = stdout.lock().flush();
        eprintln!("\nDump parsing error: {}", e);
        process::exit(1);
    }

    // Report warnings for fields not found
    for table in &config.tables {
        for field in &table.fields {
            for json_rule in &field.json {
                if json_rule.infos.nbhits == 0 {
                    eprintln!(
                        "WARNING! Field {}:{} - JSON path '{}' from config file has not been found in dump. Maybe a config file error?",
                        table.name, field.name, json_rule.filter
                    );
                }
            }
            if field.infos.nbhits == 0 {
                eprintln!(
                    "WARNING! Field {}:{} from config file has not been found in dump. Maybe a config file error?",
                    table.name, field.name
                );
            }
        }
    }

    // Stats
    if config.stats {
        let ts_end = ts_beg.elapsed().as_millis() as u64;
        let stdout = io::stdout();
        let mut out = stdout.lock();
        let _ = writeln!(out, "-- Total execution time: {} ms", ts_end);
        let _ = writeln!(out, "-- Time spent for anonymization: 0 ms");
        let mut total_anon: u64 = 0;
        for table in &config.tables {
            for field in &table.fields {
                let _ = writeln!(
                    out,
                    "-- Field {}:{} anonymized {} time(s)",
                    table.name, field.name, field.infos.nbhits
                );
                total_anon += field.infos.nbhits;
            }
        }
        let _ = writeln!(out, "-- TOTAL Number of anonymization(s): {}", total_anon);
    }
}
