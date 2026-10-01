# MultiDock

A tiny macOS app that shows a dock on every screen that doesn't have the real macOS Dock.
It mirrors your pinned Dock apps, adds running apps, and uses Liquid Glass on macOS 26.

- Finder, then your pinned Dock apps, then other running apps
- Click to launch or bring an app to the front
- Notification badges, like the real Dock (needs Accessibility permission)
- Right-click: Show in Finder, Hide, Quit, Quit MultiDock
- Follows the real Dock when it moves to another screen (within about 1s)
- No icon in the Dock or Cmd+Tab, no private APIs, no dependencies

Status: early prototype. See [PLAN.md](PLAN.md) for the roadmap (settings window, side positions, auto-hide).

## Build

Needs the Xcode Command Line Tools (`xcode-select --install`), macOS 12 or later.

```sh
scripts/make-signing-cert.sh   # optional, once: lets macOS permissions survive rebuilds
bash prototype/build.sh
open prototype/build.noindex/MultiDock.app
```

If `swiftc` fails with "this SDK is not supported by the compiler", point the build at an SDK that matches your
compiler, for example `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk bash prototype/build.sh`.

## Install

```sh
ditto prototype/build.noindex/MultiDock.app /Applications/MultiDock.app
open /Applications/MultiDock.app
```

The build is signed with your local "MultiDock Local Signing" certificate if you created it, ad-hoc otherwise.
Either way it isn't notarized, so the first time macOS may ask you to confirm opening it.

- **Badges** need Accessibility permission: System Settings > Privacy & Security > Accessibility > turn on MultiDock.
  With the signing certificate the permission survives updates. Ad-hoc builds lose it on every rebuild: then
  run `tccutil reset Accessibility io.github.barjakuzu.multidock` and grant it again.
- **Start at login:** right-click any MultiDock icon > Open at Login (macOS 13+).
- **Dock jumping:** with "Displays have separate Spaces" on, the real Dock moves to whichever screen you push the
  pointer against at the bottom. Right-click > Stop Dock Jumping Here keeps the pointer off that edge on screens
  with a MultiDock bar (on by default).

## Uninstall

Right-click any MultiDock icon, turn off Open at Login, choose Quit MultiDock, then delete `/Applications/MultiDock.app`.

## License

[MIT](LICENSE)
