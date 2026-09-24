# Used by test_pydef_json_paths.conf

def upper(value):
    return value.upper()

def tag(value, prefix):
    return prefix + ":" + value[::-1]
