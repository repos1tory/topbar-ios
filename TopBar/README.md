# TopBar

TopBar is the generalized version of RateBar: a small status-bar item host that
owns the right-side row on iPadOS, plus separate plugin dylibs for individual
items. It can reorder and hide stock status-bar items and installed plugins from
one Settings pane.

Installed packages:

- `com.alsinas.topbar` — the host and Settings pane. Conflicts with/replaces
  `com.alsinas.ratebar`.
- `com.alsinas.topbar.battery` — signed charge/drain watts + time estimate
  (the old RateBar item).
- `com.alsinas.topbar.ip` — local/public IP item. Tap it to switch between
  `L:` (local) and `W:` (public).

## Use

1. Open **Settings → TopBar** (near the bottom of the Settings root list).
2. Tap **Edit** to drag items into bar order. The list is left-to-right.
3. Use the switches to show/hide stock items and plugins. Changes apply to
   SpringBoard immediately.
4. Tap the IP item in the status bar to switch local/public. The public lookup
   uses `https://api.ipify.org` and is cached for five minutes.

The left-side time/date are owned by iOS and are not moved by this version.

## Plugins

A plugin is a normal SpringBoard tweak dylib plus a manifest:

- The dylib exposes one class named `TBPlugin_<something>` conforming to
  `TBStatusPlugin` in `src/TopBar/TBStatusPlugin.h`.
- The package installs a manifest at
  `/var/jb/Library/TopBar/Plugins/<identifier>.plist` with `Identifier`,
  `Name`, `Description`, `Version`, `Author`, and `DefaultOrder`.
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
