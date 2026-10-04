# Myanon Configuration Examples

This directory contains example myanon configuration files for popular open source applications.

## ⚠️ Important Notice

**Except for WordPress, these configurations are AI-generated and have not been tested by me.**

I do not use any of these applications personally. These examples are provided as starting points to help users create their own configurations.

The WordPress configuration has been tested on a real WordPress 7.1 + WooCommerce 11.1 database: no personal data was left in the dump, and the anonymized dump imported into a working site (roles, logins, orders and serialized settings intact).

## Available Examples

- **wordpress-myanon.conf** + **wordpress_myanon.py** - WordPress CMS with WooCommerce support (requires Python support, see below)
- **nextcloud-myanon.conf** - Nextcloud file sharing platform
- **gitlab-myanon.conf** - GitLab DevOps platform
- **drupal-myanon.conf** - Drupal content management system
- **phpbb-myanon.conf** - phpBB forum software

## Usage

1. Copy the relevant configuration file to your working directory
2. Modify the `secret` value to your own unique secret
3. Adjust table prefixes if needed (e.g., change `wp_` to your WordPress prefix)
4. Review and customize field anonymization rules for your specific needs
5. Test thoroughly with a small dataset before using on production data

## WordPress

WordPress keeps much of its personal data in key/value tables (`wp_usermeta`,
`wp_postmeta`, `wp_options`...), so its configuration relies on the Python
module `wordpress_myanon.py`. You need myanon built with Python support (the
Docker image has it, or `./configure --with-python`), and `pypath` in the
configuration must point to the directory holding the module:

```sh
cd examples
mysqldump wordpress | myanon -f wordpress-myanon.conf > anonymized.sql
```

After anonymization, every account can log in with the password `password`.

## Customization

Each configuration includes:
- User data anonymization (emails, names, passwords)
- Preservation of database relationships through deterministic hashing
- Generic placeholder content for posts/messages
- Optional table truncation for sensitive logs

You may need to:
- Add tables specific to your plugins/modules
- Adjust anonymization strategies per your requirements
- Modify field mappings based on your database schema

## Support

**If you find issues with these configurations:**

1. Please open an issue at: https://github.com/ppomes/myanon/issues
2. Include:
   - Which configuration file you're using
   - The specific error or unexpected behavior
   - Your application version (WordPress, Drupal, etc.)
   - Any customizations you made

## Contributing

Improvements to these examples are welcome! If you:
- Fix bugs in existing configurations
- Add support for additional plugins/modules
- Create configurations for other applications

Please submit a pull request with your changes.

## Disclaimer

These examples are provided "as is" without warranty. Always:
- Test configurations on non-production data first
- Verify that all sensitive data is properly anonymized
- Ensure compliance with your data protection requirements
- Backup your data before running anonymization
