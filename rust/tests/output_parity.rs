// Check that the Rust port produces the same output as the reference files
// used by `make check` for the C version.

use myanon::config::Parser;
use myanon::dump::DumpProcessor;
use std::fs;
use std::path::{Path, PathBuf};

fn repo_dir() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).join("..")
}

// Core (non-Python) tests, read from TULIST in Makefile.am so the list
// stays in sync with `make check`.
fn core_tests() -> Vec<String> {
    let makefile = fs::read_to_string(repo_dir().join("Makefile.am")).expect("Cannot read Makefile.am");
    let line = makefile
        .lines()
        .find(|l| l.starts_with("TULIST ="))
        .expect("TULIST not found in Makefile.am");
    line["TULIST =".len()..]
        .split_whitespace()
        .map(String::from)
        .collect()
}

fn run(name: &str) -> Vec<u8> {
    let dir = repo_dir().join("tests");
    let conf = fs::read_to_string(dir.join(format!("{name}.conf")))
        .unwrap_or_else(|e| panic!("Cannot read {name}.conf: {e}"));
    let mut config = Parser::new(&conf)
        .parse()
        .unwrap_or_else(|e| panic!("Failed to parse {name}.conf: {e}"));
    let input = fs::read(dir.join(format!("{name}.sql")))
        .unwrap_or_else(|e| panic!("Cannot read {name}.sql: {e}"));

    let mut output = Vec::new();
    let mut processor = DumpProcessor::new(&mut config)
        .unwrap_or_else(|e| panic!("{name}: {e}"));
    processor
        .process(&input[..], &mut output)
        .unwrap_or_else(|e| panic!("{name}: {e}"));
    output
}

#[test]
fn core_tests_match_reference_output() {
    let tests = core_tests();
    assert!(!tests.is_empty());

    let mut failures = Vec::new();
    for name in &tests {
        let expected = fs::read(repo_dir().join("tests").join(format!("{name}_anon.sql")))
            .unwrap_or_else(|e| panic!("Cannot read {name}_anon.sql: {e}"));
        if run(name) != expected {
            failures.push(name.clone());
        }
    }
    assert!(failures.is_empty(), "Output differs from the reference for: {failures:?}");
}
