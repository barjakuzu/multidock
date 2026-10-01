# Notes

## 2026-09-29: Phase 1
- The default CLT SDK (MacOSX27.0) was built by Swift 6.4 but the installed compiler is 6.3.3, so `swiftc` failed
  with "this SDK is not supported by the compiler". `build.sh` now pins `MacOSX26.sdk` (override with `SDKROOT=...`).
  Once CLT updates its compiler, the pin can go.
- Prototype compiled with no code changes, no warnings.
- Dock detection works: with 2 DELL screens, visibleFrame is cut by 76px on the Dock screen, and the bar appears only
  on the other screen (1292x70 at the bottom).
- Background switched to `NSGlassEffectView` (Liquid Glass) on macOS 26+ to match the real Dock; older systems keep
  the `.hudWindow` NSVisualEffectView. Style `.clear`: `.regular` rendered frosted white in Light mode, unlike the Dock.
  Window shadow off (the glass draws its own edge). Items live in `DockPanel.itemsView` so both paths share the layout code.

## 2026-09-30: Badges
- There is no public API for another app's badge, but the Dock's accessibility tree has it: each dock item has
  `AXStatusLabel` (badge text) and `AXURL`. Read via public AXUIElement API, so no private APIs. Needs
  Accessibility permission; without it `dockBadges()` returns [:] and the dock works as before.
- Only apps the real Dock shows can have badges (pinned or running), which covers every MultiDock item.
- Ad-hoc signing: macOS ties the Accessibility grant to the exact build, so after every rebuild you may have to
  remove MultiDock from Accessibility and add it again.

## 2026-10-01: Edge guard (experimental)
- Goal: keep "Displays have separate Spaces" on (menu bar on every screen) with the Dock at the bottom, without the
  Dock jumping to the MultiDock screen when the pointer hits its bottom edge.
- `EdgeGuard` watches mouse moves (global + local monitor, no extra permission) and warps the pointer 2pt up when it
  gets within 2pt of the bottom of a screen that has a MultiDock bar. Toggle: right-click > "Stop Dock Jumping Here"
  (UserDefaults `edgeGuard`, default on).
- Unverified: if the Dock reacts to raw mouse deltas rather than pointer position, this won't help.
- Edge guard confirmed working by the user with separate Spaces on.

## 2026-10-01: Login item, stable install
- "Open at Login" in the right-click menu uses `SMAppService.mainApp` (macOS 13+). Context menus are now built on
  every right-click so the checkmarks match the current state on all icons.
- The Accessibility prompt at every login came from rebuilding in place: the grant belonged to an older build.
  The README now installs a copy to /Applications, which gets the permission once.
- Spotlight found both the installed app and the build copy. Builds now go to `prototype/build.noindex/`, which
  Spotlight skips.
- App icon: `scripts/make-icon.swift` draws it and writes `prototype/AppIcon.icns` (committed, so builds don't
  need to run it).
- Stable signing: `scripts/make-signing-cert.sh` creates a self-signed "MultiDock Local Signing" certificate.
  The designated requirement becomes identifier + certificate leaf instead of a cdhash, so the Accessibility
  grant survives rebuilds. `build.sh` falls back to ad-hoc when the certificate is missing.
