import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"

        let menu = NSMenu()
        menu.addItem(withTitle: "Spike: Check Permissions", action: #selector(checkPermissions), keyEquivalent: "")
        menu.addItem(withTitle: "Spike: Scan Menu Bar Items", action: #selector(scanMenuBar), keyEquivalent: "")
        menu.addItem(withTitle: "Spike: Hide First Foreign Item", action: #selector(hideFirst), keyEquivalent: "")
        menu.addItem(withTitle: "Spike: Restore Hidden Item", action: #selector(restoreHidden), keyEquivalent: "")
        menu.addItem(withTitle: "Spike: Full Round-Trip (restore→click→re-hide)", action: #selector(roundTrip), keyEquivalent: "")
        menu.addItem(withTitle: "Spike: Stress x20 (hide+roundtrip loop)", action: #selector(stress), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        Log.line("launched. pid=\(getpid())")
    }

    @objc func checkPermissions() { Permissions.report() }
    @objc func scanMenuBar() { MenuBarScan.shared.logAll() }
    @objc func hideFirst() { RoundTrip.shared.hideFirstForeignItem() }
    @objc func restoreHidden() { RoundTrip.shared.restoreHidden() }
    @objc func roundTrip() { RoundTrip.shared.fullRoundTrip() }

    @objc func stress() {
        Task { @MainActor in
            for n in 1...20 {
                Log.line("stress cycle \(n)")
                RoundTrip.shared.hideFirstForeignItem()
                try? await Task.sleep(for: .milliseconds(400))
                RoundTrip.shared.restoreHidden()
                try? await Task.sleep(for: .milliseconds(400))
            }
            Log.line("stress done: 20 cycles survived")
        }
    }
}
