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
