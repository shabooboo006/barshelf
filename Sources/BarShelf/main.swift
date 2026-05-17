import AppKit
import BarShelfCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ n: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"
        let m = NSMenu()
        m.addItem(withTitle: "BarShelf v0.1.0 (skeleton)", action: nil, keyEquivalent: "")
        m.addItem(.separator())
        m.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = m
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // LSUIElement agent
let delegate = AppDelegate()
app.delegate = delegate
app.run()
