#!/bin/zsh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="/var/jb/tmp/TopBarBuildRoot"
THEOS="${THEOS:-/var/jb/var/mobile/theos}"

rm -rf "$BUILD"
mkdir -p "$BUILD"
cp -R "$ROOT/." "$BUILD/"
rm -rf "$BUILD/.git" "$BUILD/.theos" "$BUILD/packages" \
       "$BUILD/TopBar/.theos" "$BUILD/TopBar/packages" \
       "$BUILD/plugins/battery/.theos" "$BUILD/plugins/ip/.theos" \
       "$BUILD/tools/probe/packages" "$BUILD/tools/prefprobe/packages"
chmod -R u+rwX,go+rX "$BUILD"
umask 022
export THEOS

if [[ "${DEBUG:-0}" == "1" ]]; then
    MAKE_FLAGS=(DEBUG=1)
else
    MAKE_FLAGS=(FINALPACKAGE=1)
fi

make -C "$BUILD/TopBar" package "${MAKE_FLAGS[@]}" SHELL=/var/jb/bin/bash
for plugin in battery ip network weather cpu ram thermal disk sessions; do
    make -C "$BUILD/plugins/$plugin" package "${MAKE_FLAGS[@]}" SHELL=/var/jb/bin/bash
done

mkdir -p "$ROOT/packages"
cp "$BUILD"/TopBar/packages/com.alsinas.topbar_*.deb "$ROOT/packages/"
for plugin in battery ip network weather cpu ram thermal disk sessions; do
    cp "$BUILD"/plugins/$plugin/packages/com.alsinas.topbar.*_*.deb "$ROOT/packages/"
done

# TopBar is the replacement host for the original single-purpose RateBar.
sudo dpkg -r com.alsinas.ratebar com.alsinas.topbarprobe com.alsinas.prefprobe \
    com.alsinas.appprobe com.alsinas.appbarprobe com.alsinas.scopeprobe >/dev/null 2>&1 || true
sudo dpkg -i --force-downgrade \
    "$BUILD"/TopBar/packages/com.alsinas.topbar_*.deb \
    "$BUILD"/plugins/*/packages/*.deb

sudo sbreload || sudo killall -9 SpringBoard
sleep 8

echo "--- installed"
dpkg -l | grep -E 'topbar|ratebar' || true
echo "--- plugins"
sudo ls -l /var/jb/Library/TopBar/Plugins 2>/dev/null || true
echo "Open Settings → TopBar to enable, hide, or reorder items."
