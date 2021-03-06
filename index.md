# Myanon

Myanon is a MySQL dump anonymizer, reading a dump from stdin, and producing an anonymized version to stdout.

Anonymization is done through a deterministic hmac processing based on sha-256. When used on fields acting as foreign keys, constraints are kept.

A configuration file is used to store the hmac secret and to select which fields need to be anonymized.

This tool is in alfa stage. Please report any issue.

## Simple use case

Example to create both a real crypted (sensitive) backup and an anonymized (non-sentitive) backup from a single mysqldump command:

```
mysqldump mydb | tee >(myanon -f myanon.cfg | gzip > mydb_anon.sql.gz) |\
  gpg -e -r me@domain.com > mydb.sql.gz.gpg
```
