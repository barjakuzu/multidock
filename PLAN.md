# MultiDock: Implementation Plan

## Goal

A lightweight macOS menu bar app that shows a dock on every screen that doesn't have the real macOS Dock. It mirrors the user's pinned Dock apps, adds running apps, and lets the user open, switch, hide and quit apps from any monitor.

## Current state

`prototype/main.swift` + `prototype/build.sh` is a single-file working draft. It was written without access to a Mac and has **never been compiled**. Treat it as a reference for the approach, not as finished code.

What the prototype already does:

- Reads pinned apps from `com.apple.dock` `persistent-apps` (CFPreferences), always adds Finder first
- Appends running regular apps (by launch date), dedupes by normalized bundle path
- Detects which screen has the system Dock by comparing `NSScreen.frame` with `visibleFrame`
- Creates one borderless, non-activating `NSPanel` per target screen at Dock window level, on all Spaces
- Click opens/activates the app via `NSWorkspace.openApplication`; right-click menu: Show in Finder, Hide, Quit, Quit MultiDock
- Running indicator dot, hover grow effect, tooltip with app name
- Refreshes on app launch/quit, space change, screen changes, and a 1s timer (the Dock moving has no notification). Only redraws when a signature string changes.

## Requirements

### Must have (v1)

1. Builds with Xcode Command Line Tools only (`swift build` / `swiftc`), no Xcode project required.
2. Runs as an agent app (`LSUIElement`), no icon in the real Dock or Cmd+Tab.
3. Shows a dock bar on every screen except the one hosting the system Dock. Follows the system Dock when it moves (within ~1s).
4. Items: Finder, then pinned apps from the real Dock, then other running apps. Missing apps on disk are skipped.
5. Left click: launch or bring to front (reopen a window if none open, same as the real Dock).
6. Right click menu: Show in Finder, Hide, Quit (running apps only), Quit MultiDock.
7. Running indicator and hover feedback. Follows light/dark mode.
8. Menu bar icon (`NSStatusItem`) with: Settings, Refresh, Quit.
9. Settings (stored in `UserDefaults`, applied live):
   - Position: bottom / left / right
   - Icon size: 32 to 72
   - Auto-hide: on/off (reveal when the cursor hits that screen edge, hide after ~0.5s away)
   - Show on: "screens without the Dock" (default) / "all screens"
10. Launch at login toggle using `SMAppService.mainApp` (macOS 13+). Hide the toggle on older systems.
11. Bar never exceeds screen size. If too many items, shrink icons to fit (down to 24px) before clipping.
12. Low CPU when idle (target under 1% average). No redraw if nothing changed.

### Nice to have (v2, only after v1 is done and tested)

- Drag an app icon off to remove it from MultiDock's own extra list, drag an .app in to add
- Separate pinned list for MultiDock instead of mirroring the real Dock (setting)
- Trash and Downloads stack at the end
- [x] Badge counts (done via the Dock's accessibility tree, no private API)

### Out of scope

- Replacing or modifying the real Dock
- App Store distribution, sandboxing, notarization

## Target structure

Convert the prototype into a Swift Package:

```
MultiDock/
  Package.swift                      // macOS 12+, executable target + library target + tests
  Sources/
    MultiDockCore/                   // pure logic, no AppKit windows, unit-testable
      AppEntry.swift
      EntryCollector.swift           // pinned + running merge, dedupe, key normalization
      DockPrefsReader.swift          // reads com.apple.dock persistent-apps
      ScreenDockDetector.swift       // frame vs visibleFrame logic, takes plain CGRects
      Settings.swift                 // UserDefaults-backed settings model + change notifications
    MultiDock/
      main.swift
      AppController.swift            // observers, timer, signature diff, panel lifecycle
      DockPanel.swift                // NSPanel, layout per position, auto-hide
      ItemView.swift                 // icon, indicator, hover, click, context menu
      StatusMenu.swift               // NSStatusItem menu
      SettingsWindow.swift           // small SwiftUI or AppKit settings window
  Tests/
    MultiDockCoreTests/
  scripts/
    build-app.sh                     // swift build -c release, assemble .app, ad-hoc sign
    make-zip.sh                      // zips MultiDock.app for sharing
  README.md
```

Key rule: anything that can be tested without a window (detection, merging, settings) lives in `MultiDockCore` and takes plain values (CGRect, URL, arrays) so tests don't need real screens or running apps.

## Phases and tasks

Phases 1 and 2 must be done in order. After phase 2, the tracks in phase 3 can run in parallel with separate agents.

### Phase 1: Get the prototype running (single agent)

- [x] Compile `prototype/main.swift` with `prototype/build.sh`, fix all errors and warnings
- [ ] Run it with 2 screens, confirm: bar appears on the non-Dock screen, clicks work, context menu works, bar moves when the Dock moves
- [ ] Write down any behavior that differs from the "Current state" list in `NOTES.md`

Done when: the app runs on the developer's Mac and the manual checks above pass.

### Phase 2: Restructure (single agent)

- [ ] Create the Swift Package layout above, move code into files, no behavior changes
- [ ] Extract pure logic into `MultiDockCore`
- [ ] Add `scripts/build-app.sh` (release build, Info.plist with LSUIElement, ad-hoc codesign)
- [ ] Add unit tests for: key normalization, pinned + running merge order and dedupe, missing-app skip, Dock screen detection (bottom, left, right, auto-hidden ~4px, none detected fallback)

Done when: `swift build`, `swift test` and `scripts/build-app.sh` all succeed, and behavior matches phase 1.

### Phase 3: Features (parallel tracks)

**Track A: Layout and auto-hide** (`DockPanel`, `ItemView`)
- [ ] Positions bottom / left / right with correct vertical layout for side positions
- [ ] Icon size setting and shrink-to-fit
- [ ] Auto-hide with edge reveal (global mouse monitor or tracking window at the edge), smooth slide animation
- [ ] "Show on all screens" mode

**Track B: Menu bar and settings** (`StatusMenu`, `SettingsWindow`, `Settings`)
- [ ] Status item with Settings, Refresh, Quit
- [ ] Settings window with all v1 settings, changes post a notification the controller listens to
- [~] Launch at login via `SMAppService` (right-click toggle in the prototype, not yet confirmed working)

**Track C: Quality** (tests, scripts, docs)
- [ ] Tests for `Settings` defaults and persistence
- [ ] Measure idle CPU with Activity Monitor, reduce timer work if above target (e.g. read Dock prefs only every 5s)
- [ ] `scripts/make-zip.sh`, `README.md` with build, install, login item and uninstall steps

Coordination: Track A and B both touch `AppController`. Track B owns `Settings.swift`; Track A reads settings only through it. Agree on the `Settings` API first (see below) so both can work at once.

```swift
enum DockPosition: String { case bottom, left, right }
enum ScreenMode: String { case withoutSystemDock, all }

final class Settings {
    static let shared: Settings
    static let didChange: Notification.Name
    var position: DockPosition        // default .bottom
    var iconSize: CGFloat             // default 48, clamp 32...72
    var autoHide: Bool                // default false
    var screenMode: ScreenMode        // default .withoutSystemDock
    var launchAtLogin: Bool           // wraps SMAppService
}
```

### Phase 4: Final check (single agent)

- [ ] Full manual test list below on the real multi-monitor setup
- [ ] Fresh clone build from README instructions only
- [ ] Final `MultiDock.zip` produced by `scripts/make-zip.sh`

## Manual test checklist

- [ ] 2+ screens: bar on every non-Dock screen, none on the Dock screen
- [ ] Move the real Dock to another screen: bars update within ~1s
- [ ] Unplug / plug a monitor: no crash, bars match the new layout
- [ ] Change resolution or arrangement: bars reposition
- [ ] Switch Spaces and enter a fullscreen app: bar behaves sensibly (hidden in fullscreen is acceptable)
- [ ] Launch and quit apps: indicator dots and extra items update
- [ ] Click a running app with no windows (e.g. Finder): a window opens
- [ ] Right-click menu actions all work
- [ ] Light and dark mode both look right
- [ ] Each setting applies live without restart
- [ ] Launch at login works after reboot
- [ ] Idle CPU under 1%

## Known risks

- `persistent-apps` format is undocumented and may change between macOS versions. Fail safe: if it can't be read, show Finder + running apps only.
- Detecting the Dock screen via `visibleFrame` may not work when the Dock is auto-hidden on some macOS versions. The fallback (skip the primary screen) must stay.
- Dock window level may place the bar above some system UI. If it causes trouble, try `.statusBar` or `.floating`.
- The bar covers the bottom of maximized windows on that screen. Auto-hide is the answer for users who mind.
