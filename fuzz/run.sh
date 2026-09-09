#!/bin/sh
# Run an AFL++ campaign against the dump parser.
#
# Usage: fuzz/run.sh [seconds] [afl-fuzz options...]
#   seconds  stop after this long (default: run until Ctrl-C)
#
# Seeds are the test dumps under tests/ smaller than 20 KB. Findings land in
# fuzz/out/default/crashes and fuzz/out/default/hangs. Reproduce one with:
#   main/myanon -f fuzz/fuzz.conf < fuzz/out/default/crashes/id:000000,...
set -e
cd "$(dirname "$0")/.."

[ -x main/myanon ] || { echo "run fuzz/build.sh first" >&2; exit 1; }
main/myanon --version 2>/dev/null | head -1

# Treat the first argument as the duration only when it is a non-negative
# integer; anything else (e.g. an afl-fuzz option like -M) is left in "$@".
secs=0
case ${1-} in
    '')       ;;
    *[!0-9]*) ;;
    *)        secs=$1; shift ;;
esac

mkdir -p fuzz/in fuzz/out
for f in tests/*.sql; do
    [ "$(stat -c %s "$f")" -lt 20000 ] && cp "$f" fuzz/in/
done
# A tiny hand-made seed keeps the mutator close to the interesting statements.
cat > fuzz/in/mini.sql <<'SQL'
CREATE TABLE `points` (`name` varchar(20), `owner` json, `emails` text, `contacts` json);
INSERT INTO `points` VALUES ('bob','{"email":"a@b.c","last_name":"x"}','a@b.c,d@e.f','["g@h.i"]'),('al',NULL,'','[]');
SQL

# ASan needs unlimited memory; AFL_SKIP_CPUFREQ / core_pattern checks only
# print advice we cannot act on from a script.
export AFL_SKIP_CPUFREQ=1
export AFL_I_DONT_CARE_ABOUT_MISSING_CRASHES=1
export AFL_NO_AFFINITY=1
# Resume automatically when fuzz/out already holds a campaign; without this
# afl-fuzz refuses to reuse a non-empty output directory.
export AFL_AUTORESUME=1
export ASAN_OPTIONS=abort_on_error=1:symbolize=0:detect_leaks=0:allocator_may_return_null=1

timeout_opt=""
[ "$secs" -gt 0 ] && timeout_opt="-V $secs"

exec afl-fuzz -i fuzz/in -o fuzz/out -m none -t 2000 -x fuzz/sql.dict $timeout_opt "$@" \
    -- main/myanon -f fuzz/fuzz.conf
