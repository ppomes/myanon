# Used by test_pydef_json_long.conf
#
# Returns a value far larger than both the old fixed JSON replacement buffer
# (CONFIG_SIZE) and the old 16-bit result length (65535).

def long_value(value):
    return "L" * 70000
