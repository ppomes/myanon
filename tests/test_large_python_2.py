def sanitize_user_settings(value):
    if not value:
        return value

    lines = value.split('\\n')
    result = []
    for line in lines:
        if "s_paypal_email:" in line:
            indent = line.split("s_paypal_email: ")[0]
            result.append(f"{indent}s_paypal_email: hidden@example.com")
        else:
           result.append(line)
    return '\\n'.join(result)
