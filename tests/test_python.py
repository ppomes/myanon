import myanon_utils

def pytest(value):
   # Unescape the input from the dump
   clean_value = myanon_utils.unescape_sql_string(value)

   # Apply your logic on clean text
   reversed_value = clean_value[::-1]

   # Escape the result for SQL output
   return myanon_utils.escape_sql_string(reversed_value)
