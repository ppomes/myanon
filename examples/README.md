# Myanon Configuration Examples

This directory contains myanon configurations for popular open source applications.

## Tested configurations

Each configuration was tested on a real installation filled with recognizable personal data: after anonymization, none of it was left in the dump, and the anonymized dump imported into a working application.

| Application | Files | Tested with |
|---|---|---|
| WordPress + WooCommerce | `wordpress-myanon.conf`, `wordpress_myanon.py` | WordPress 7.1, WooCommerce 11.1, MySQL 8.4 |
| Nextcloud | `nextcloud-myanon.conf`, `nextcloud_myanon.py` | Nextcloud 35, MariaDB 11 |
| Drupal | `drupal-myanon.conf`, `drupal_myanon.py` | Drupal 11.4, MariaDB 11 |
| phpBB | `phpbb-myanon.conf`, `phpbb_myanon.py` | phpBB 3.3.19, MySQL 8.4 |

They are still starting points: plugins, modules and apps you add store personal data in tables of their own, which you need to add.

## Usage

All four configurations rely on a Python module, because these applications keep personal data in key/value tables, serialized values or copies of user names that can only be handled with some logic. You need myanon built with Python support (the Docker image has it, or `./configure --with-python`).

1. Copy the configuration file and its Python module to the same directory
2. Change the `secret` value
3. Set `pypath` to the directory holding the module (relative paths are relative to the directory myanon is run from)
4. Adjust the table prefix if yours differs from the default
5. Run it, then check the result before sharing the dump

```sh
cd examples
mysqldump wordpress | myanon -f wordpress-myanon.conf > anonymized.sql
```

## What the configurations do

- Accounts are renamed (`user<ID>`, or `u<letters>` for Nextcloud) and every password becomes `password`.
- Names, e-mails, phone numbers, addresses and IP addresses are replaced. The same real value always gets the same fake value, in every table, so relationships between users, orders, comments and so on are kept.
- IDs, dates, statuses, roles and serialized data are left intact, so the application keeps working.
- Free text written by people (comments, forum posts, private messages) becomes placeholder text.
- Sessions, tokens, logs, caches and search indexes are deleted.

Some application-specific notes:

- **Nextcloud**: user file names are renamed too, and contacts and calendar events are deleted. The data directory is not part of the dump, so files are listed but their content is missing. Run `occ dav:sync-system-addressbook` after import.
- **Drupal**: fields added to users (`user__field_<name>` tables) must each be added to the configuration. Caches are rebuilt on the next request.
- **phpBB**: bots and the anonymous user are left untouched. Rebuild the search index from the ACP after import.

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
