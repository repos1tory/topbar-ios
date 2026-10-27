# TopBar

Source: [repos1tory/topbar-ios](https://github.com/repos1tory/topbar-ios).

TopBar is the generalized version of RateBar: a small status-bar item host that
owns the left and right status-bar rows on iPadOS, plus separate plugin dylibs
for individual items. It can reorder and hide stock status-bar items and
installed plugins from one Settings pane.

Installed packages:

- `com.alsinas.topbar` — the host and Settings pane. Conflicts with/replaces
  `com.alsinas.ratebar`.
- `com.alsinas.topbar.battery` — signed charge/drain watts + time estimate
  (the old RateBar item).
- `com.alsinas.topbar.ip` — local/public IP item. Tap it to switch between
  `L:` (local) and `W:` (public).
- Additional items: `com.alsinas.topbar.network` (↓/↑ throughput),
  `com.alsinas.topbar.weather` (temperature + condition),
  `com.alsinas.topbar.cpu` (CPU load), `com.alsinas.topbar.ram` (memory usage),
  `com.alsinas.topbar.thermal` (battery temperature in °C), and
  `com.alsinas.topbar.disk` (free/total storage). Also
  `com.alsinas.topbar.sessions` (running OpenCode sessions),
  `com.alsinas.topbar.batteryhealth` (health/cycles/adapter watts),
  `com.alsinas.topbar.sunmoon` (sunrise/sunset/moon), and
  `com.alsinas.topbar.uptime` (time since boot).

## Use

1. Open **Settings → TopBar** (near the bottom of the Settings root list).
2. Tap **Edit** to drag items into bar order. The list has **Left Side** and
   **Right Side** sections; drag a plugin between sections to move it to that
   side.
3. Use the switches to show/hide stock items and plugins. Changes apply to
   SpringBoard immediately.
4. Tap the IP item in the status bar to switch local/public. The public lookup
   uses `https://api.ipify.org` and is cached for five minutes.

The left side groups **Time & Date** as one stock item; it can be hidden or
reordered with left-side plugins. The clock and date are not split into two
separate items in this version.

## Scope

TopBar hooks SpringBoard's `STUIStatusBar` instances. On iPadOS the
Home Screen and app status bars are both SpringBoard-owned `STUIStatusBar`
instances (the app one lives in `SBMainSwitcherWindow`), so the same host
applies in apps such as Settings and Safari as well as on the Home Screen.
It does not modify a status bar rendered inside an app's own process; it also
does not show in UI where iOS hides the status bar.

## Plugins

A plugin is a normal SpringBoard tweak dylib plus a manifest:

- The dylib exposes one class named `TBPlugin_<something>` conforming to
  `TBStatusPlugin` in `src/TopBar/TBStatusPlugin.h`.
- The package installs a manifest at
  `/var/jb/Library/TopBar/Plugins/<identifier>.plist` with `Identifier`,
  `Name`, `Description`, `Version`, `Author`, `DefaultOrder`, and optionally
  `Side` (`left` or `right`). The protocol may also implement `pluginSide`.
- After installing a plugin package, respring once so SpringBoard loads the
  dylib. The manifest appears in Settings immediately; the host shows it as
  “respring to load” until the class is available.

Minimal protocol:

```objc
- (NSString *)pluginIdentifier;   // must match the manifest Identifier
- (NSString *)pluginDisplayName;
- (NSString *)statusText;         // current text
- (void)refresh;                  // called about every 2 seconds
@optional
- (BOOL)wantsTap;
- (void)handleTap;
- (NSString *)pluginSide;         // optional: @"left" or @"right"
```

See `plugins/battery` and `plugins/ip` for complete examples.

## Build and install

Theos cannot build from a path containing spaces, so the script copies the
project to `/var/jb/tmp/TopBarBuildRoot` first.

```sh
export THEOS=/var/jb/var/mobile/theos
./tools/build-install-topbar.sh
```

The release `.deb`s are copied to `packages/`. To build a debug package and get
the layout log at `/var/jb/tmp/topbar-debug.txt`:

```sh
DEBUG=1 ./tools/build-install-topbar.sh
```

The host writes shared state under
`/var/mobile/Library/Preferences/com.alsinas.topbar*.plist`.

`tools/probe` and `tools/prefprobe` are development-only diagnostics for
checking the private status-bar hierarchy and Settings row; they are not part
of the installed packages.
