# Myanon

Myanon is a MySQL dump anonymizer, reading a dump from stdin, and producing an anonymized version to stdout.

Anonymization is done through a deterministic hmac processing based on sha-256. When used on fields acting as foreign keys, constraints are kept.

However, an optional python support can be used to define custom anonymization rules (python faker for example)

Myanon works by default on flat (numeric and text) fields and has built-in support for JSON fields.

A configuration file is used to store the hmac secret and to select which fields need to be anonymized. A self-commented sample is provided (main/myanon-sample.conf)

This tool is in alpha stage. Please report any issue.

## Notable Changes

### Version 0.8 (upcoming)
- **Removed jq dependency**: JSON field anonymization is now handled by a built-in parser, eliminating the need for the external jq library. The `--enable-jq` configure option is now deprecated but still accepted for backward compatibility.

## Simple use case

Example to create both a real crypted (sensitive) backup and an anonymized (non-sensitive) backup from a single mysqldump command:

```
mysqldump mydb | tee >(myanon -f myanon.cfg | gzip > mydb_anon.sql.gz) | gpg -e -r me@domain.com > mydb.sql.gz.gpg
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

Example on a Fedora system: 

```shell
$ sudo dnf install autoconf automake gcc make flex bison
$ sudo dnf install python3-devel # For optional python support
[...]
```
Example on a Debian/Ubuntu system:

```shell
$ sudo apt-get install autoconf automake flex bison build-essential
$ sudo apt-get install python3-dev # For optional python support
[...]
```
On macOS, you need to install Xcode and homebrew, and then:
```shell
$ brew install autoconf automake flex bison m4
$ brew install python3 # For optional python support
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
make
make install
```

### Compilation/link flags

Flags are controlled by using CFLAGS/LDFLAGS when invoking make.
To create a debug build:
```
make CFLAGS="-O0 -g"
```

To create a static executable file on Linux and minimal build only  
```
make LDFLAGS="-static"
```

### Python support

When Python support is enabled (`--enable-python`), custom anonymization functions can be defined in Python scripts. These scripts have access to a `myanon_utils` module that provides functions to retrieve configuration parameters:

- `get_secret()`: Returns the HMAC secret defined in the configuration file

This allows Python anonymization functions to use the same secret as the core anonymization process, ensuring consistency across all anonymized fields.


### Run/Tests
```
main/myanon -f tests/test1.conf < tests/test1.sql
zcat tests/test2.sql.gz | main/myanon -f tests/test2.conf
```
The tests directory contains examples with basic hmac anonymization, and with python rules (faker). 

## Installation from packages (Ubuntu)

A PPA is available at: https://launchpad.net/~pierrepomes/+archive/ubuntu/myanon

## Docker Build / Run

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

