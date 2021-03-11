---
title: "A mysqldump anomymizer"
title-heading: false
---

## What is Myanon?

Myanon is a *mysqldump* anonymizer, reading a dump from stdin, and producing an anonymized version to stdout.

Anonymization is done through a deterministic hmac processing based on sha-256. When used on fields acting as foreign keys, constraints are kept.

A configuration file is used to store the hmac secret and to select which fields need to be anonymized. Text, integer and email fields can be anonymized.

This tool is in alpha stage. Please report any issue on here ({{site.github.issues_url}})

## Configuration notes

Here is a configuration example:
```
#
# Myanon sample config file
#

secret = 'mysecret'
stats  = 'yes'

tables = {
   `people` = {
     `lastname`   = texthash 10
     `firstname`  = texthash 10
     `age`        = inthash 2
     `email`      = emailhash 'example.com' 10
     `division`   = fixed 'mycompany'
   }
}
``` 
* `secret` - hmac secret.
* `stats`  - when set to 'yes', some stats are added as SQL comments at the end of the anonymized dump: total processing time, anonymization spent time, number of anonymized fields.
* `tables` - a list of table and fields to be processed.

Each table and field needs to be back-quoted (same as in mysql dump file). For each field, the following options are available:
* `texthash N` - creates a hash for text value, N chars long, up to 32 chars.  
* `inthash N` - creates a hash for integer value, N digits long, up to 32 digits.
* `emailmash 'domain.com' N` - creates a hash for email, ending with 'domain.com', N chars long (including domain), up to 32 chars
* `fixed 'myvalue'` - creates a constant text value 'myvalue' 


## Technical notes

Written C, Myanon is small (less than 300Kb stripped), and consumes only a few megabytes of RAM. 

As processing a dump file is a sequential process, Myanon is single-threaded, but is quite fast, because it does not rely on any external SQL parser. When reading the dump file, it looks only for 'CREATE TABLE' and 'INSERT INTO' statements on tables specified in the configuration file. Any other statements are copied from stdin to stdout without any unnecessary parsing.


## Simple use case

Example to create both a real crypted (sensitive) backup and an anonymized (non-sentitive) backup from a single mysqldump command:

```
mysqldump mydb |\
  tee >(myanon -f myanon.cfg | gzip > mydb_anon.sql.gz) |\
  gpg -e -r me@domain.com > mydb.sql.gz.gpg
```
