#!/bin/sh
# Build an AFL++-instrumented myanon with AddressSanitizer and
# UndefinedBehaviorSanitizer, in-tree, without Python support.
#
# Usage: fuzz/build.sh            (from the repository root)
#
# Afterwards, `./autogen.sh && ./configure` restores a normal build.
set -e
cd "$(dirname "$0")/.."

command -v afl-clang-fast >/dev/null || { echo "afl-clang-fast not found: apt install afl++ clang" >&2; exit 1; }

make distclean >/dev/null 2>&1 || true
./autogen.sh
./configure --without-python \
    CC=afl-clang-fast \
    CFLAGS="-g -O1 -fsanitize=address,undefined -fno-omit-frame-pointer -fno-sanitize-recover=undefined"
make -j"$(nproc)"
echo "Instrumented binary: main/myanon"
