# Myanon

Myanon is a MySQL dump anonymizer, reading a dump from stdin, and producing an anonymized version to stdout.

Anonymization is done through a deterministic hmac processing based on sha-256. When used on fields acting as foreign keys, constraints are kept.

A configuration file is used to store the hmac secret and to select which fields need to be anonymized. A self-commented sample is provided (main/myanon-sample.conf)

This tool is in alfa stage. Please report any issue.

## Simple use case

Example to create both a real crypted (sensitive) backup and an anonymized (non-sentitive) backup from a single mysqldump command:

```
mysqldump mydb | tee >(myanon -f myanon.cfg | gzip > mydb_anon.sql.gz) | gpg -e -r me@domain.com > mydb.sql.gz.gpg
```

## Build (Linux)
```
./autogen.sh
./configure
make
```

## Build (macOS)
```
brew install autoconf
brew install automake
brew install flex
brew install bison
./autogen.sh
./configure
make
```

## Compilation/link flags

flags are controlled by using CFLAGS/LDFLAGS when invoking make.
To create a debug build:
```
make CFLAGS="-O0 -g"
```

To create a static build on Linux:
```
make LDFLAGS="-static"
```


## Run/Tests
```
main/myanon -f tests/test1.conf < tests/test1.sql
main/myanon -f tests/test2.conf < tests/test2.sql
```
