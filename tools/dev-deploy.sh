#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="/var/jb/tmp/RateBarBuild"
THEOS="${THEOS:-/var/jb/var/mobile/theos}"

rm -rf "$BUILD"
mkdir -p "$BUILD"
cp -R "$ROOT/." "$BUILD/"
chmod -R u+rwX,go+rX "$BUILD"
umask 022
export THEOS

make -C "$BUILD" package DEBUG=1 SHELL=/var/jb/bin/bash

sudo dpkg -i "$BUILD"/packages/com.alsinas.ratebar_*_iphoneos-arm64.deb
sudo sbreload
sleep 8

echo "--- SpringBoard"
launchctl list | grep -i springboard || true
echo "--- debug file"
sudo cat /var/jb/tmp/ratebar-debug.txt 2>/dev/null | tail -30 || true
echo "--- debug prefs"
sudo plutil -extract RateBarDebugLines json -o - /var/mobile/Library/Preferences/com.apple.springboard.plist 2>/dev/null | tail -20 || true
