# Myanon

Fast MySQL dump anonymizer.

- **Deterministic hashing**: built-in HMAC-SHA256 rules always produce the same output for the same input -- foreign key relationships are preserved automatically
- **Fast**: processes dumps as a stream with zero intermediate storage
- **JSON-aware**: built-in parser for anonymizing fields inside JSON columns
- **Extensible**: optional Python support for custom anonymization logic (e.g. Faker)

## Quick demo

**Config** (`myanon.conf`):
```
secret = 'my_secret_key'

tables = {
  `users` = {
    `name`  = texthash 8
    `email` = emailhash 'example.com' 20
    `phone` = fixed null
  }
}
```

**Run**:
```
mysqldump mydb | myanon -f myanon.conf > anonymized.sql
```

**Before** (original dump):
```sql
INSERT INTO `users` VALUES (1,'Alice Martin','alice.martin@corp.com','555-867-5309');
INSERT INTO `users` VALUES (2,'Bob Johnson','bob.johnson@corp.com','555-123-4567');
```

**After** (anonymized dump):
```sql
INSERT INTO `users` VALUES (1,'kducynmt','brtqbnlokywxzafpghej@example.com',NULL);
INSERT INTO `users` VALUES (2,'wpxldjca','tsmgkrebvufdxihonalq@example.com',NULL);
```

Referential integrity is preserved: if `bob.johnson@corp.com` appears in another table with the same `emailhash` rule, it produces the same anonymized value.

## Features

| Rule | Description |
|------|-------------|
| `texthash N` | Hash text value to N hex chars (up to 32) |
| `inthash N` | Hash integer value to N digits (up to 32) |
| `emailhash 'domain' N` | Hash email, N chars total, with given domain |
| `fixed 'value'` | Replace with a constant (supports `quoted`/`unquoted` modifiers) |
| `fixed null` | Replace with NULL |
| `key` | Mark a column as the key for `appendkey`/`prependkey` references |
| `appendkey 'prefix'` / `prependkey 'suffix'` | Deterministic value tied to the row's key column |
| `appendindex 'prefix'` / `prependindex 'suffix'` | Value tied to the row's position (1-based) |
| `substring N` | Truncate the field value to the first N characters |
| `json { path 'x.y' = ... }` | Anonymize specific paths inside JSON columns (supports nested objects and arrays with `[]`) |
| `truncate` | Drop all data from a table (removes INSERT/UPDATE statements) |
| `pydef 'func'` | Call a custom Python function |
| `separated by ','` | Modifier: apply the rule to each value in a delimited field |
| `regex` table names | Match multiple tables with a single rule (e.g. `` regex `(prod\|test)users` ``) |

## Installation

### Package (Ubuntu)

A PPA is available at: https://launchpad.net/~pierrepomes/+archive/ubuntu/myanon

### Docker

```shell
docker build --tag myanon .
docker run -it --rm -v ${PWD}:/app myanon sh -c '/bin/myanon -f /app/myanon.conf < /app/dump.sql > /app/dump-anon.sql'
```

See [Docker details](#docker-build--run) below for Apple Silicon notes and more.

### Building from source (C)

Requirements: autoconf, automake, make, a C compiler (gcc or clang), flex, bison. Optional: python3-dev, libssl-dev (for `--with-openssl`).

```
./autogen.sh
./configure                     # Minimal build (includes JSON support)
./configure --enable-python     # With optional Python support
./configure --with-openssl      # Use OpenSSL for hardware-accelerated HMAC-SHA256
make
make install
```

See [full build instructions](#installation-from-sources) below for per-distro packages and more options.

## Configuration

A self-documented sample config is provided in [`main/myanon-sample.conf`](main/myanon-sample.conf).

**Global directives**:
- `secret` -- the HMAC secret (up to 64 chars)
- `stats` -- report anonymization statistics as SQL comments at the end of the dump (`yes`/`no`)
- `pypath` / `pyscript` -- path and module name for Python custom functions

**Tables block**: list tables and columns with their anonymization rules. Table names can be literal or regex-matched. Table and column names must be back-quoted (e.g. `` `users` ``), matching the format used by mysqldump output.

### Simple use case

Example to create both a real encrypted (sensitive) backup and an anonymized (non-sensitive) backup from a single mysqldump command:

```
mysqldump mydb | tee >(myanon -f myanon.cfg | gzip > mydb_anon.sql.gz) | gpg -e -r me@domain.com > mydb.sql.gz.gpg
```

## Python support

When Python support is enabled (`--enable-python`), custom anonymization functions can be defined in Python scripts. These scripts have access to a `myanon_utils` module that provides utility functions:

- `get_secret()`: Returns the HMAC secret defined in the configuration file
- `escape_sql_string(str)`: Escapes a string for safe SQL insertion
- `unescape_sql_string(str)`: Unescapes a SQL-escaped string

This allows Python anonymization functions to handle SQL strings properly and use the same secret as the core anonymization process, ensuring consistency across all anonymized fields.

## Docker build / run

### tl;dr:

```shell
docker build --tag myanon .
docker run -it --rm -v ${PWD}:/app myanon sh -c '/bin/myanon -f /app/myanon.conf < /app/dump.sql | gzip > /app/dump-anon.sql.gz'
```

### Why Docker?
An alternative to the above build or run options is to use the provided Dockerfile to build inside an isolated environment, and run `myanon` from a container.

It's useful when:

* you can't or don't want to install a full C development environment on your host
* you want to quickly build for or run on a different architecture (e.g.: `amd64` or `arm64`)
* you want to easily distribute a self-contained `myanon` (e.g.: for remote execution & processing on a Kubernetes cluster)

The provided multistage build `Dockerfile` is using the [`alpine` Docker image](https://hub.docker.com/_/alpine/).

### Build using Docker

Build a binary using the provided `Dockerfile`:

```shell
# recommended, to start from a clean state
make clean
# build using your default architecture
docker build --tag myanon .
```

For Apple Silicon users who want to build for `amd64`:

```shell
# recommended, to start from a clean state
make clean
# build using the amd64 architecture
docker build --tag myanon --platform=linux/amd64 .
```

### Run using Docker

In this example we will:

* use a `myanon` configuration file (`myanon.conf`)
* use a MySQL dump (`dump.sql`)
* generate an anonymized dump (`dump-anon.sql`) based on the configuration and the full dump.

Sharing the local folder as `/app` on the Docker host:

```shell
docker run -it --rm -v ${PWD}:/app myanon sh -c '/bin/myanon -f /app/myanon.conf < /app/dump.sql > /app/dump-anon.sql'
```

For Apple Silicon users who want to run as `amd64`:

```shell
docker run -it --rm --platform linux/amd64 -v ${PWD}:/app myanon sh -c '/bin/myanon -f /app/myanon.conf < /app/dump.sql > /app/dump-anon.sql'
```

## Installation from sources

### Build Requirements

- autoconf
- automake
- make
- a C compiler (gcc or clang)
- flex
- bison
- python (optional)
- libssl-dev / openssl-devel (optional, for `--with-openssl`)

Example on a Fedora system:

```shell
$ sudo dnf install autoconf automake gcc make flex bison
$ sudo dnf install python3-devel   # For optional python support
$ sudo dnf install openssl-devel   # For optional --with-openssl
[...]
```
Example on a Debian/Ubuntu system:

```shell
$ sudo apt-get install autoconf automake flex bison build-essential
$ sudo apt-get install python3-dev  # For optional python support
$ sudo apt-get install libssl-dev   # For optional --with-openssl
[...]
```
On macOS, you need to install Xcode and homebrew, and then:
```shell
$ brew install autoconf automake flex bison m4
$ brew install python3  # For optional python support
$ brew install openssl  # For optional --with-openssl
[...]
```

(Please ensure binaries installed by brew are in your $PATH)

If you are using zsh, you may need to add the following to your .zshrc file:

```shell
export PATH="/usr/local/opt/m4/bin:$PATH"
export PATH="/usr/local/opt/flex/bin:$PATH"
export PATH="/usr/local/opt/bison/bin:$PATH"
```

For Apple Silicon at build time, you may need to adjust include and library search path:
```shell
export CFLAGS=-I/opt/homebrew/include
export LDFLAGS=-L/opt/homebrew/lib
```

### Build/Install

```
./autogen.sh
./configure                             # Minimal build (includes JSON support)
./configure --enable-python             # With optional python support
./configure --with-openssl              # Use OpenSSL for hardware-accelerated HMAC-SHA256
make
make install
```

### Compilation/link flags

Flags are controlled by using CFLAGS/LDFLAGS when invoking make.
To create a debug build:
```
make CFLAGS="-O0 -g"
```

To create a static executable file on Linux (without Python support)
```
make LDFLAGS="-static"
```

### Run/Tests
```
main/myanon -f tests/test1.conf < tests/test1.sql
zcat tests/test2.sql.gz | main/myanon -f tests/test2.conf
```
The tests directory contains examples with basic hmac anonymization, and with python rules (faker).

## Rust implementation (vibe-coding experiment)

An alternative Rust implementation is available in the `rust/` directory, created entirely through vibe-coding with [Claude Code](https://claude.com/claude-code). It produces identical output to the C version and passes all 14 tests, requiring only a Rust toolchain (no flex/bison/autotools).

```
cd rust
cargo build --release                   # Without Python support
cargo build --release --features python # With Python support (requires python3-dev)
```

The binary is at `rust/target/release/myanon`. Usage is the same as the C version.