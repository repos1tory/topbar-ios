#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="/var/jb/tmp/RateBarBuild"
THEOS="${THEOS:-/var/jb/var/mobile/theos}"

rm -rf "$BUILD"
mkdir -p "$BUILD"
cp -R "$ROOT/." "$BUILD/"
rm -rf "$BUILD/packages" "$BUILD/.git" "$BUILD/.theos"
chmod -R u+rwX,go+rX "$BUILD"
umask 022
export THEOS

make -C "$BUILD" package FINALPACKAGE=1 SHELL=/var/jb/bin/bash

mkdir -p "$ROOT/packages"
cp "$BUILD"/packages/com.alsinas.ratebar_*_iphoneos-arm64.deb "$ROOT/packages/"
ls -l "$ROOT"/packages/*.deb
