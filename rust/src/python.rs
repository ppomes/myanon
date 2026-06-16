use pyo3::prelude::*;
use pyo3::types::{PyDict, PyModule};
use std::ffi::CString;
use std::path::Path;

/// Holds a reference to the imported Python module and the HMAC secret.
pub struct PythonRunner {
    module: Py<PyModule>,
    utils_module: Py<PyModule>,
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

        Python::attach(|py| {
            // Create the myanon_utils module with get_secret, get_row, get_table,
            // unescape_sql_string, escape_sql_string
            let utils_code = format!(
                r#"
_current_row = {{}}
_current_table = ""

def get_secret():
    return {secret_repr}

def get_row():
    return _current_row

def get_table():
    return _current_table

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
                .set_item("myanon_utils", &utils_module)
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
                utils_module: utils_module.into(),
            })
        })
    }

    /// Publish the current row context (table name + field/value pairs) into
    /// `myanon_utils._current_table` and `myanon_utils._current_row`.
    /// Field names are passed with surrounding backticks to match the C API.
    pub fn set_row(&self, table: &str, row: &[(String, String)]) -> Result<(), String> {
        Python::attach(|py| {
            let utils = self.utils_module.bind(py);
            let dict = PyDict::new(py);
            for (k, v) in row {
                dict.set_item(k, v).map_err(|e| {
                    e.print(py);
                    "Failed to set row item".to_string()
                })?;
            }
            utils.setattr("_current_row", dict).map_err(|e| {
                e.print(py);
                "Failed to publish _current_row".to_string()
            })?;
            utils.setattr("_current_table", table).map_err(|e| {
                e.print(py);
                "Failed to publish _current_table".to_string()
            })?;
            Ok(())
        })
    }

    /// Call a named function in the user's Python module.
    /// If `params` is empty, the function is called with a single string argument `(value,)`.
    /// Otherwise it is called with `(value, params)`.
    pub fn call(&self, func_name: &str, value: &str, params: &str) -> Result<String, String> {
        Python::attach(|py| {
            let module = self.module.bind(py);
            let func = module.getattr(func_name).map_err(|e| {
                e.print(py);
                format!("Python function '{}' not found", func_name)
            })?;
            let result = if params.is_empty() {
                func.call1((value,))
            } else {
                func.call1((value, params))
            }
            .map_err(|e| {
                e.print(py);
                format!("Python function '{}' call failed", func_name)
            })?;
            let result_str: String = result.extract::<String>().map_err(|e| {
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
