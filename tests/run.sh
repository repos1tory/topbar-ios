#!/bin/zsh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${SDK:-/var/jb/usr/share/SDKs/iPhoneOS.sdk}"
OUT="${TMPDIR:-/var/jb/tmp}/ratebar-tests"

clang -fobjc-arc -miphoneos-version-min=15.0 -isysroot "$SDK" \
    -framework Foundation \
    -o "$OUT" \
    "$ROOT/tests/RateMathTests.m" "$ROOT/src/RateMath.m"

"$OUT"
