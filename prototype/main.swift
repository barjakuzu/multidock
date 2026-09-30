// MultiDock: shows a dock on every screen that doesn't currently have the macOS Dock.
// Pinned apps are read from your real Dock, running apps are added after them.

import AppKit

let iconSize: CGFloat = 48
let itemWidth: CGFloat = 58
let barHeight: CGFloat = 70
let bottomGap: CGFloat = 4

struct AppEntry {
    let url: URL
    let name: String
    let app: NSRunningApplication?
    var badge: String? = nil
}

func key(_ url: URL) -> String {
    url.standardizedFileURL.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
}

// Pinned apps from the system Dock (com.apple.dock persistent-apps)
func pinnedApps() -> [URL] {
    let domain = "com.apple.dock" as CFString
    CFPreferencesAppSynchronize(domain)
    guard let tiles = CFPreferencesCopyAppValue("persistent-apps" as CFString, domain) as? [[String: Any]] else { return [] }
    return tiles.compactMap { tile in
        guard let td = tile["tile-data"] as? [String: Any],
              let fd = td["file-data"] as? [String: Any],
              let s = fd["_CFURLString"] as? String else { return nil }
        return s.hasPrefix("file://") ? URL(string: s) : URL(fileURLWithPath: s)
    }
}

// Badges ("1", "3", "•") shown on the real Dock, keyed like key(_:). Read through the Dock's
// accessibility tree, so it needs Accessibility permission; returns [:] without it.
func dockBadges() -> [String: String] {
    guard AXIsProcessTrusted(),
          let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [:] }
    func attr(_ e: AXUIElement, _ a: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(e, a as CFString, &v) == .success ? v : nil
    }
    var result: [String: String] = [:]
    for list in attr(AXUIElementCreateApplication(dock.processIdentifier), kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        for item in attr(list, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
            if let badge = attr(item, "AXStatusLabel") as? String, !badge.isEmpty,
               let url = attr(item, kAXURLAttribute) as? URL {
                result[key(url)] = badge
            }
        }
    }
    return result
}

func collectEntries() -> [AppEntry] {
    let running = NSWorkspace.shared.runningApplications
        .filter { $0.activationPolicy == .regular && $0.bundleURL != nil }
    var byKey: [String: NSRunningApplication] = [:]
    for r in running { byKey[key(r.bundleURL!)] = r }

    var result: [AppEntry] = []
    var seen = Set<String>()
    let finder = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")

    for url in [finder] + pinnedApps() {
        let k = key(url)
        guard !seen.contains(k), FileManager.default.fileExists(atPath: url.path) else { continue }
        seen.insert(k)
        result.append(AppEntry(url: url, name: FileManager.default.displayName(atPath: url.path), app: byKey[k]))
    }
    let sorted = running.sorted { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
    for r in sorted {
        let url = r.bundleURL!
        if seen.insert(key(url)).inserted {
            result.append(AppEntry(url: url, name: r.localizedName ?? url.lastPathComponent, app: r))
        }
    }
    let badges = dockBadges()
    for i in result.indices { result[i].badge = badges[key(result[i].url)] }
    return result
}

// A screen has the system Dock if its visible area is cut at the bottom, left or right
func hasSystemDock(_ s: NSScreen) -> Bool {
    let f = s.frame, v = s.visibleFrame
    return v.minY > f.minY + 1 || v.minX > f.minX + 1 || v.maxX < f.maxX - 1
}

func displayID(_ s: NSScreen) -> CGDirectDisplayID {
    (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? 0
}

final class ItemView: NSView {
    let entry: AppEntry
    let icon: NSImage
    var hovering = false { didSet { needsDisplay = true } }

    init(entry: AppEntry) {
        self.entry = entry
        self.icon = NSWorkspace.shared.icon(forFile: entry.url.path)
        super.init(frame: NSRect(x: 0, y: 0, width: itemWidth, height: barHeight))
        toolTip = entry.name
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
        menu = buildMenu()
    }
    required init?(coder: NSCoder) { fatalError() }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
    override func mouseDown(with event: NSEvent) {}
    override func mouseUp(with event: NSEvent) {
        guard bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        // Launches the app, or brings it forward (and reopens a window) if it's running
        NSWorkspace.shared.openApplication(at: entry.url, configuration: cfg)
    }

    override func draw(_ dirtyRect: NSRect) {
        let size = hovering ? iconSize + 6 : iconSize
        let rect = NSRect(x: (bounds.width - size) / 2, y: 14 - (hovering ? 2 : 0), width: size, height: size)
        icon.draw(in: rect)
        if entry.app != nil {
            NSColor.labelColor.withAlphaComponent(0.8).setFill()
            NSBezierPath(ovalIn: NSRect(x: bounds.midX - 2, y: 4, width: 4, height: 4)).fill()
        }
        if let badge = entry.badge { drawBadge(badge, iconRect: rect) }
    }

    // Red pill at the icon's top-right corner, like the real Dock
    func drawBadge(_ text: String, iconRect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                                                    .foregroundColor: NSColor.white]
        let t = NSAttributedString(string: text, attributes: attrs)
        let h: CGFloat = 18
        let w = max(h, t.size().width + 10)
        let pill = NSRect(x: min(iconRect.maxX - 13, bounds.maxX - w), y: min(iconRect.maxY - 13, bounds.maxY - h),
                          width: w, height: h)
        NSColor.systemRed.setFill()
        NSBezierPath(roundedRect: pill, xRadius: h / 2, yRadius: h / 2).fill()
        t.draw(at: NSPoint(x: pill.midX - t.size().width / 2, y: pill.midY - t.size().height / 2))
    }

    func buildMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "").target = self
        if entry.app != nil {
            m.addItem(withTitle: "Hide", action: #selector(hideApp), keyEquivalent: "").target = self
            m.addItem(withTitle: "Quit", action: #selector(quitApp), keyEquivalent: "").target = self
        }
        m.addItem(.separator())
        m.addItem(withTitle: "Quit MultiDock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "").target = NSApp
        return m
    }
    @objc func showInFinder() { NSWorkspace.shared.activateFileViewerSelecting([entry.url]) }
    @objc func hideApp() { entry.app?.hide() }
    @objc func quitApp() { entry.app?.terminate() }
}

final class DockPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)))
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        if #available(macOS 26.0, *) {
            // Liquid Glass, same material as the real Dock on macOS 26
            let glass = NSGlassEffectView()
            glass.cornerRadius = 22
            glass.style = .clear
            glass.contentView = itemsView
            contentView = glass
        } else {
            let fx = NSVisualEffectView()
            fx.material = .hudWindow
            fx.blendingMode = .behindWindow
            fx.state = .active
            fx.wantsLayer = true
            fx.layer?.cornerRadius = 16
            fx.layer?.masksToBounds = true
            fx.addSubview(itemsView)
            itemsView.autoresizingMask = [.width, .height]
            contentView = fx
        }
    }
    let itemsView = NSView()
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func show(_ entries: [AppEntry], on screen: NSScreen) {
        let fx = itemsView
        fx.subviews.forEach { $0.removeFromSuperview() }
        for (i, e) in entries.enumerated() {
            let v = ItemView(entry: e)
            v.frame.origin = NSPoint(x: 8 + CGFloat(i) * itemWidth, y: 0)
            fx.addSubview(v)
        }
        let f = screen.frame
        let w = min(CGFloat(entries.count) * itemWidth + 16, f.width - 20)
        setFrame(NSRect(x: f.midX - w / 2, y: f.minY + bottomGap, width: w, height: barHeight), display: true)
        orderFrontRegardless()
    }
}

final class Controller: NSObject, NSApplicationDelegate {
    var panels: [CGDirectDisplayID: DockPanel] = [:]
    var lastSignature = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Asks once for Accessibility permission (needed for badges); everything else works without it
        AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        let wc = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification,
                     NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.activeSpaceDidChangeNotification] {
            wc.addObserver(self, selector: #selector(refresh), name: name, object: nil)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refresh),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        // The Dock moving between screens has no notification, so check every second
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in self?.refresh() }
        refresh()
    }

    @objc func refresh() {
        let screens = NSScreen.screens
        var targets = screens.filter { !hasSystemDock($0) }
        if targets.count == screens.count, screens.count > 1 {
            // Couldn't tell where the Dock is: skip the primary screen
            targets = Array(screens.dropFirst())
        }
        if screens.count == 1 { targets = [] }

        let entries = collectEntries()
        let sig = targets.map { "\(displayID($0))@\(NSStringFromRect($0.frame))" }.joined(separator: ",")
            + "|" + entries.map { key($0.url) + ($0.app != nil ? "*" : "") + ($0.badge.map { "#" + $0 } ?? "") }.joined(separator: ",")
        guard sig != lastSignature else { return }
        lastSignature = sig

        let ids = Set(targets.map(displayID))
        for (id, panel) in panels where !ids.contains(id) {
            panel.orderOut(nil)
            panels[id] = nil
        }
        for s in targets {
            let id = displayID(s)
            let panel = panels[id] ?? DockPanel()
            panels[id] = panel
            panel.show(entries, on: s)
        }
    }
}

let app = NSApplication.shared
let controller = Controller()
app.delegate = controller
app.setActivationPolicy(.accessory)
app.run()
