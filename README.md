# RateBar

A single signed number and an estimated time beside the iPad status bar battery
percentage:

```
+6.2W 3h30m   26%   [battery]
-3.1W 1h07m   12%   [battery]
```

- **Positive** means the battery is charging.
- **Negative** means the battery is draining.
- **0W** means the battery is full on AC or the current is below the display threshold.
- The time is **until full** when charging and **until empty** when draining.
- The time is omitted when it is not meaningful or not available.

The number is **watts into or out of the battery**, calculated from the battery
current and voltage (`InstantAmperage` / `Amperage` × `Voltage`). It is not the
charger's advertised wattage. One decimal place and a `W` unit are shown.

The sign follows the actual battery current, so a plugged-in iPad can still show
a negative number when the screen/CPU are using more power than the charger
supplies. That is not a bug: the battery is draining.

## Behavior

- Reads `IOPMPowerSource` through IOKit in SpringBoard. Read-only; it never
  changes charging or power state.
- Updates every 2 seconds and on power-source notifications.
- Uses the stock battery percentage's font, size, weight and adaptive text
  colour. Digits are made tabular so the number does not jitter.
- Sits immediately left of the stock battery percentage.
- To make room on iPad, the status icons immediately left of the battery
  percentage (Wi-Fi, rotation lock, Focus, etc.) are shifted left by the exact
  width of the rate and time. The shift is recalculated when the text changes or
  when an icon appears/disappears. They are restored if the label hides. This is
  a small layout adjustment, not a replacement of the stock status bar.
- iPad only in this version. On iPhone the label is not shown because the
  status bar is too tight to make room without covering stock items.

## Time estimates

- **Draining:** uses iOS's own `TimeRemaining` estimate when available, then
  falls back to remaining mAh ÷ current.
- **Charging:** remaining mAh ÷ current charge current. It updates as the charge
  rate tapers, so the number can get longer as the battery fills.
- When the iPad is plugged in but the load exceeds the charger, the watts are
  negative and the time shown is **time to empty**, because the battery really
  is draining.
- These are estimates, not promises. A heavy app, brightness change, or thermal
  throttle can move the drain estimate quickly.

## Compatibility

- Rootless jailbreak, ElleKit.
- iPadOS 15 or later.
- Built and tested on an **iPad7,5 / iPadOS 17.7.8** with a rootless jailbreak.

## Published

Published on [repos1tory](https://repos1tory.github.io/) as
`com.alsinas.ratebar` 0.2.1. Sileo depiction:
<https://repos1tory.github.io/sileo/com.alsinas.ratebar.json>.

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

The tests cover the sign convention, zero/full handling, duration formatting,
and time-to-full/time-to-empty math.

## Limits

- No preferences yet; the label is always enabled.
- The rate is battery-side power, so it will be lower than the wall/charger
  wattage while charging.
- The number is formatted as one decimal; very small flows show `0`.
- The status bar layout is private API and may change in a future iPadOS.
