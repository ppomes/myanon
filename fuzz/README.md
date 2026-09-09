# Fuzzing myanon

The dump read on stdin is untrusted input: it contains whatever users stored in
the database. It goes through three hand-written flex/bison parsers (dump,
JSON inside JSON columns, and the config file) and into fixed-size buffers.
This directory holds what is needed to fuzz the dump parser with
[AFL++](https://github.com/AFLplusplus/AFLplusplus).

## One-time setup

```sh
sudo apt install afl++ clang
echo core | sudo tee /proc/sys/kernel/core_pattern   # until next reboot
```

The `core_pattern` change stops Ubuntu's apport from intercepting crashes,
which would otherwise make AFL++ see them as timeouts.

## Build the instrumented binary

```sh
fuzz/build.sh
```

This does an in-tree build without Python, compiled with `afl-clang-fast`,
AddressSanitizer and UndefinedBehaviorSanitizer. `make check` still passes on
it, so it doubles as a sanitizer run of the test suite. To get a normal build
back afterwards: `./autogen.sh && ./configure --with-python && make`.

## Run

```sh
fuzz/run.sh          # until Ctrl-C
fuzz/run.sh 3600     # stop after one hour
```

Seeds are the test dumps under `tests/` smaller than 20 KB plus a tiny
hand-made one. `fuzz/fuzz.conf` names the tables of most seed dumps and uses
every non-Python anonymisation type, so mutated dumps reach as much code as
possible. `fuzz/sql.dict` gives the mutator SQL and JSON tokens.

Extra options are passed to `afl-fuzz`. For a parallel run on several cores,
start one main and several secondaries:

```sh
fuzz/run.sh 0 -M main &
fuzz/run.sh 0 -S s1 &
fuzz/run.sh 0 -S s2 &
```

## Triage

Findings land in `fuzz/out/default/crashes/` and `fuzz/out/default/hangs/`
(`fuzz/out/<name>/` for parallel runs). Reproduce one and get a symbolised
sanitizer report with:

```sh
ASAN_OPTIONS=symbolize=1 main/myanon -f fuzz/fuzz.conf < 'fuzz/out/default/crashes/id:000000,...'
```

`afl-tmin` shrinks a crashing input to its essential bytes:

```sh
afl-tmin -m none -i 'fuzz/out/default/crashes/id:000000,...' -o small.sql -- main/myanon -f fuzz/fuzz.conf
```

## Other targets

- Config parser: `afl-fuzz ... -- main/myanon -f @@ < tests/test1.sql`, seeded
  with `tests/*.conf`. Lower priority: the config file is trusted.
- JSON parser: it is reached through JSON columns, so a config with `json {}`
  paths (as `fuzz.conf` has) and seeds with JSON values cover it.
