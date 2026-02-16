use pyo3::prelude::*;
use pyo3::types::PyModule;
use std::ffi::CString;
use std::path::Path;

/// Holds a reference to the imported Python module and the HMAC secret.
pub struct PythonRunner {
    module: Py<PyModule>,
}

impl PythonRunner {
    /// Initialize the Python interpreter, register the `myanon_utils` module,
    /// add `pypath` to `sys.path`, and import the user's script.
    pub fn new(pypath: &str, pyscript: &str, secret: String) -> Result<Self, String> {
        // Resolve pypath to absolute
        let abs_pypath = if Path::new(pypath).is_absolute() {
            pypath.to_string()
        } else {
            std::env::current_dir()
                .map_err(|e| format!("Failed to get current dir: {}", e))?
                .join(pypath)
                .to_string_lossy()
                .to_string()
        };

        Python::with_gil(|py| {
            // Create the myanon_utils module with get_secret, unescape_sql_string, escape_sql_string
            let utils_code = format!(
                r#"
def get_secret():
    return {secret_repr}

def unescape_sql_string(s):
    result = []
    i = 0
    while i < len(s):
        if s[i] == '\\' and i + 1 < len(s):
            c = s[i + 1]
            if c == "'":
                result.append("'")
                i += 2
            elif c == '\\':
                result.append('\\')
                i += 2
            elif c == '"':
                result.append('"')
                i += 2
            else:
                result.append('\\')
                i += 1
        elif s[i] == "'" and i + 1 < len(s) and s[i + 1] == "'":
            result.append("'")
            i += 2
        else:
            result.append(s[i])
            i += 1
    return ''.join(result)

def escape_sql_string(s):
    result = []
    for c in s:
        if c == "'":
            result.append("''")
        elif c == '\\':
            result.append('\\\\')
        else:
            result.append(c)
    return ''.join(result)
"#,
                secret_repr = format!("{:?}", secret)
            );

            let utils_code_c = CString::new(utils_code)
                .map_err(|_| "Python utils code contains null bytes".to_string())?;
            let filename_c = c"myanon_utils.py";
            let modname_c = c"myanon_utils";
            let utils_module = PyModule::from_code(
                py,
                &utils_code_c,
                filename_c,
                modname_c,
            )
            .map_err(|e| {
                e.print(py);
                "Failed to create myanon_utils module".to_string()
            })?;

            // Register in sys.modules
            let sys = py.import("sys").map_err(|e| {
                e.print(py);
                "Failed to import sys".to_string()
            })?;
            let modules = sys.getattr("modules").map_err(|e| {
                e.print(py);
                "Failed to get sys.modules".to_string()
            })?;
            modules
                .set_item("myanon_utils", utils_module)
                .map_err(|e| {
                    e.print(py);
                    "Failed to register myanon_utils in sys.modules".to_string()
                })?;

            // Add pypath to sys.path
            let sys_path = sys.getattr("path").map_err(|e| {
                e.print(py);
                "Failed to get sys.path".to_string()
            })?;
            sys_path.call_method1("insert", (0, &abs_pypath)).map_err(|e| {
                e.print(py);
                format!("Failed to add {} to sys.path", abs_pypath)
            })?;

            // Import user's script module
            let module = py.import(pyscript).map_err(|e| {
                e.print(py);
                format!("Failed to import Python module '{}'", pyscript)
            })?;

            Ok(PythonRunner {
                module: module.into(),
            })
        })
    }

    /// Call a named function in the user's Python module with a single string argument.
    /// Returns the result as a String.
    pub fn call(&self, func_name: &str, value: &str) -> Result<String, String> {
        Python::with_gil(|py| {
            let module = self.module.bind(py);
            let func = module.getattr(func_name).map_err(|e| {
                e.print(py);
                format!("Python function '{}' not found", func_name)
            })?;
            let result = func.call1((value,)).map_err(|e| {
                e.print(py);
                format!("Python function '{}' call failed", func_name)
            })?;
            let result_str: String = result.extract().map_err(|e| {
                e.print(py);
                format!(
                    "Python function '{}' did not return a string",
                    func_name
                )
            })?;
            Ok(result_str)
        })
    }
}

#[cfg(test)]
mod tests {
    /// Unescape a SQL string: \' → ', \\ → \, \" → ", '' → '
    fn unescape_sql_string(input: &str) -> String {
        let bytes = input.as_bytes();
        let len = bytes.len();
        let mut result = String::with_capacity(len);
        let mut i = 0;
        while i < len {
            if bytes[i] == b'\\' && i + 1 < len {
                match bytes[i + 1] {
                    b'\'' => {
                        result.push('\'');
                        i += 2;
                    }
                    b'\\' => {
                        result.push('\\');
                        i += 2;
                    }
                    b'"' => {
                        result.push('"');
                        i += 2;
                    }
                    _ => {
                        result.push('\\');
                        i += 1;
                    }
                }
            } else if bytes[i] == b'\'' && i + 1 < len && bytes[i + 1] == b'\'' {
                result.push('\'');
                i += 2;
            } else {
                result.push(bytes[i] as char);
                i += 1;
            }
        }
        result
    }

    /// Escape a string for SQL output: ' → '', \ → \\
    fn escape_sql_string(input: &str) -> String {
        let mut result = String::with_capacity(input.len());
        for c in input.chars() {
            match c {
                '\'' => {
                    result.push('\'');
                    result.push('\'');
                }
                '\\' => {
                    result.push('\\');
                    result.push('\\');
                }
                _ => result.push(c),
            }
        }
        result
    }

    #[test]
    fn test_unescape_sql_string() {
        assert_eq!(unescape_sql_string(r"hello"), "hello");
        assert_eq!(unescape_sql_string(r"it\'s"), "it's");
        assert_eq!(unescape_sql_string(r"a\\b"), "a\\b");
        assert_eq!(unescape_sql_string(r#"he\"llo"#), "he\"llo");
        assert_eq!(unescape_sql_string("it''s"), "it's");
        assert_eq!(unescape_sql_string(r"O\'Connel"), "O'Connel");
    }

    #[test]
    fn test_escape_sql_string() {
        assert_eq!(escape_sql_string("hello"), "hello");
        assert_eq!(escape_sql_string("it's"), "it''s");
        assert_eq!(escape_sql_string("a\\b"), "a\\\\b");
    }

    #[test]
    fn test_roundtrip() {
        let original = "O'Connel";
        let escaped = escape_sql_string(original);
        assert_eq!(escaped, "O''Connel");
        let unescaped = unescape_sql_string(&escaped);
        assert_eq!(unescaped, original);
    }
}
