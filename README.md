# RateBar

A single signed number beside the iPad status bar battery percentage:

```
+5.3W  20%  [battery]
```

- **Positive** means the battery is charging.
- **Negative** means the battery is draining.
- **0** means the battery is full on AC or the current is below the display threshold.

The number is **watts into or out of the battery**, calculated from the battery
current and voltage (`InstantAmperage` / `Amperage` × `Voltage`). It is not the
charger's advertised wattage. One decimal place and a `W` unit are shown.

## Behavior

- Reads `IOPMPowerSource` through IOKit in SpringBoard. Read-only; it never
  changes charging or power state.
- Updates every 2 seconds and on power-source notifications.
- Uses the stock battery percentage's font size and adaptive text colour.
- Sits immediately left of the stock battery percentage.
- To make room on iPad, the status icons immediately left of the battery
  percentage (Wi-Fi, rotation lock, Focus, etc.) are shifted left by the width
  of the number. They are restored if the label hides. This is a small layout
  adjustment, not a replacement of the stock status bar.
- iPad only in this version. On iPhone the label is not shown because the
  status bar is too tight to make room without covering stock items.

## Compatibility

- Rootless jailbreak, ElleKit.
- iPadOS 15 or later.
- Built and tested on an **iPad7,5 / iPadOS 17.7.8** with a rootless jailbreak.

## Build

Theos cannot build from a path containing spaces. The build scripts copy the
project to `/var/jb/tmp/RateBarBuild` first.

```sh
export THEOS=/var/jb/var/mobile/theos
./tools/build-release.sh
```

The package is copied to `packages/`.

## Install

```sh
sudo dpkg -i packages/com.alsinas.ratebar_*_iphoneos-arm64.deb
sudo sbreload
```

Uninstall:

```sh
sudo dpkg -r com.alsinas.ratebar
sudo sbreload
```

## Development

`./tools/dev-deploy.sh` builds a debug package, installs it, resprings, and
prints debug layout data. Debug builds write to
`/var/jb/tmp/ratebar-debug.txt`; release builds contain no debug logging.

## Tests

```sh
./tests/run.sh
```

The tests cover the sign convention, zero/full handling, and formatting.

## Limits

- No preferences yet; the label is always enabled.
- The rate is battery-side power, so it will be lower than the wall/charger
  wattage while charging.
- The number is formatted as one decimal; very small flows show `0`.
- The status bar layout is private API and may change in a future iPadOS.
