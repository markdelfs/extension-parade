import AppKit
import ServiceManagement
import Sparkle

final class ParadeView: NSView {
    var icons: [NSImage] = []
    var count = 0 { didSet { needsDisplay = true } }
    var iconSize: CGFloat = 40
    override func draw(_ dirtyRect: NSRect) {
        for i in 0..<min(count, icons.count) {
            let rect = NSRect(x: CGFloat(i) * (iconSize + 8), y: 4, width: iconSize, height: iconSize)
            NSGraphicsContext.current?.imageInterpolation = .none
            icons[i].draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
        }
    }
}

final class Overlay: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    let defaults = UserDefaults.standard
    var item: NSStatusItem!
    var panel: Overlay!
    let view = ParadeView()
    var timer: Timer?
    var generation = 0
    var layoutTimer: Timer?
    var updater: SPUStandardUpdaterController!
    var looping: Bool { defaults.bool(forKey: "loop") }
    var size: CGFloat { let n = defaults.double(forKey: "size"); return n > 0 ? n : 80 }
    var interval: Double { let n = defaults.double(forKey: "interval"); return n > 0 ? n : 0.65 }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let folder = Bundle.main.resourceURL!.appendingPathComponent("Icons")
        let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        view.icons = urls.filter { $0.pathExtension == "icns" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { NSImage(contentsOf: $0) }
        panel = Overlay(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.contentView = view
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "square.stack.3d.up", accessibilityDescription: "Extension Parade")
        updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        rebuildMenu()
        layoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { if self?.panel.isVisible == true { self?.reposition() } }
        }
        NotificationCenter.default.addObserver(self, selector: #selector(reposition), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(wake), name: NSWorkspace.didWakeNotification, object: nil)
        play()
        if CommandLine.arguments.contains("--smoke-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                print("SMOKE icons=\(self.view.icons.count) visible=\(self.view.count) frame=\(self.panel.frame) ignoresMouse=\(self.panel.ignoresMouseEvents)")
                NSApp.terminate(nil)
            }
        }
    }
    func menuItem(_ title: String, _ action: Selector, state: Bool? = nil, tag: Int = 0) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = self; i.tag = tag
        if let state { i.state = state ? .on : .off }
        return i
    }
    func rebuildMenu() {
        let m = NSMenu()
        let title = NSMenuItem(title: "Extension Parade", action: nil, keyEquivalent: ""); title.isEnabled = false; m.addItem(title)
        m.addItem(menuItem("Replay Parade", #selector(play)))
        m.addItem(menuItem("Stop / Hide", #selector(stop)))
        m.addItem(.separator())
        m.addItem(menuItem("Loop Parade", #selector(toggleLoop), state: looping))
        m.addItem(menuItem("Keep Icons Visible", #selector(toggleKeep), state: defaults.bool(forKey: "keep")))
        let sizes = NSMenu(); for n in [32, 48, 64, 80, 96, 128] { sizes.addItem(menuItem("\(n) px", #selector(setSize(_:)), state: Int(size) == n, tag: n)) }
        let si = NSMenuItem(title: "Icon Size", action: nil, keyEquivalent: ""); si.submenu = sizes; m.addItem(si)
        let speeds = NSMenu(); for (name, n) in [("Brisk", 350), ("Classic", 650), ("Leisurely", 1000)] { speeds.addItem(menuItem(name, #selector(setSpeed(_:)), state: Int((interval * 1000).rounded()) == n, tag: n)) }
        let sp = NSMenuItem(title: "Loading Speed", action: nil, keyEquivalent: ""); sp.submenu = speeds; m.addItem(sp)
        m.addItem(menuItem("Launch at Login", #selector(toggleLogin), state: SMAppService.mainApp.status == .enabled))
        m.addItem(.separator())
        let update = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: ""); update.target = updater; m.addItem(update)
        m.addItem(menuItem("About Extension Parade", #selector(about)))
        m.addItem(menuItem("Quit Extension Parade", #selector(quit)))
        item.menu = m
    }
    @objc func reposition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let f = screen.frame, v = screen.visibleFrame
        let dock = UserDefaults(suiteName: "com.apple.dock")
        let orientation = dock?.string(forKey: "orientation") ?? "bottom"
        let width = min(CGFloat(view.icons.count) * (size + 8) - 8, f.width - 32)
        let height = size + 8
        let y = orientation == "bottom" ? max(v.minY, f.minY) + 4 : f.minY + 4
        view.iconSize = min(size, max(16, (width + 8) / CGFloat(max(1, view.icons.count)) - 8))
        panel.setFrame(NSRect(x: f.minX + 12, y: y, width: width, height: height), display: true)
    }
    @objc func play() {
        generation += 1; let token = generation
        timer?.invalidate(); view.count = 0; panel.alphaValue = 1; reposition(); panel.orderFrontRegardless()
        addNext(token)
    }
    func addNext(_ token: Int) {
        guard token == generation else { return }
        if view.count < view.icons.count {
            view.count += 1
            timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.addNext(token) }
            }
        } else if !defaults.bool(forKey: "keep") || looping {
            timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.finish(token) }
            }
        }
    }
    func finish(_ token: Int) {
        guard generation == token else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.8; panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            DispatchQueue.main.async {
                guard let self, self.generation == token else { return }
                self.panel.orderOut(nil)
                if self.looping {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                        MainActor.assumeIsolated { guard self?.generation == token else { return }; self?.play() }
                    }
                }
            }
        }
    }
    @objc func stop() { generation += 1; timer?.invalidate(); panel.orderOut(nil) }
    @objc func toggleLoop() { defaults.set(!looping, forKey: "loop"); rebuildMenu(); play() }
    @objc func toggleKeep() { defaults.set(!defaults.bool(forKey: "keep"), forKey: "keep"); rebuildMenu(); play() }
    @objc func setSize(_ sender: NSMenuItem) { defaults.set(sender.tag, forKey: "size"); rebuildMenu(); play() }
    @objc func setSpeed(_ sender: NSMenuItem) { defaults.set(Double(sender.tag) / 1000, forKey: "interval"); rebuildMenu(); play() }
    @objc func wake() { play() }
    @objc func toggleLogin() {
        do { if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() } }
        catch { NSApp.activate(ignoringOtherApps: true); let alert = NSAlert(); alert.messageText = "Couldn’t change Launch at Login"; alert.informativeText = error.localizedDescription; alert.runModal() }
        rebuildMenu()
    }
    @objc func about() { NSApp.activate(ignoringOtherApps: true); NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "Extension Parade", .applicationVersion: "1.0.2", .credits: NSAttributedString(string: "A little startup ritual, inspired by Mac OS 9.\nYour extensions, one at a time, above the Dock.")]) }
    @objc func quit() { NSApp.terminate(nil) }
}
MainActor.assumeIsolated {
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()

}
