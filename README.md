# MultiDock

A tiny macOS app that shows a dock on every screen that doesn't have the real macOS Dock.
It mirrors your pinned Dock apps, adds running apps, and uses Liquid Glass on macOS 26.

- Finder, then your pinned Dock apps, then other running apps
- Click to launch or bring an app to the front
- Right-click: Show in Finder, Hide, Quit, Quit MultiDock
- Follows the real Dock when it moves to another screen (within about 1s)
- No icon in the Dock or Cmd+Tab, no private APIs, no dependencies

Status: early prototype. See [PLAN.md](PLAN.md) for the roadmap (settings, side positions, auto-hide, launch at login).

## Build

Needs the Xcode Command Line Tools (`xcode-select --install`), macOS 12 or later.

```sh
bash prototype/build.sh
open prototype/MultiDock.app
```

If `swiftc` fails with "this SDK is not supported by the compiler", point the build at an SDK that matches your
compiler, for example `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk bash prototype/build.sh`.

## Install

Copy `prototype/MultiDock.app` to `/Applications`. The app is ad-hoc signed, so the first time you open it,
right-click it and choose Open.

To start it at login: System Settings > General > Login Items > add MultiDock.

## Uninstall

Right-click any MultiDock icon, choose Quit MultiDock, then delete `MultiDock.app`.

## License

[MIT](LICENSE)
