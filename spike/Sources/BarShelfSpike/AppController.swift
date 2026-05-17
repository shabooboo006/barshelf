import AppKit

@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"

        let menu = NSMenu()
        menu.addItem(withTitle: "① 检查权限", action: #selector(checkPermissions), keyEquivalent: "")
        menu.addItem(withTitle: "② 扫描菜单栏图标", action: #selector(scanMenuBar), keyEquivalent: "")
        menu.addItem(withTitle: "③ 隐藏第一个外部图标", action: #selector(hideFirst), keyEquivalent: "")
        menu.addItem(withTitle: "④ 恢复已隐藏图标", action: #selector(restoreHidden), keyEquivalent: "")
        menu.addItem(withTitle: "⑤ 完整往返（恢复→点击→重新隐藏）", action: #selector(roundTrip), keyEquivalent: "")
        menu.addItem(withTitle: "⑥ 压力测试 ×20（隐藏+往返循环）", action: #selector(stress), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "显示日志窗口", action: #selector(showLog), keyEquivalent: "l")
        menu.addItem(withTitle: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        LogConsole.shared.show()
        Log.line("已启动。pid=\(getpid())。请按 ① → ⑥ 顺序操作，失败即停。")
    }

    @objc func checkPermissions() { Permissions.report() }
    @objc func scanMenuBar() { MenuBarScan.shared.logAll() }
    @objc func hideFirst() { RoundTrip.shared.hideFirstForeignItem() }
    @objc func restoreHidden() { RoundTrip.shared.restoreHidden() }
    @objc func roundTrip() { RoundTrip.shared.fullRoundTrip() }
    @objc func showLog() { LogConsole.shared.show() }

    @objc func stress() {
        Task { @MainActor in
            for n in 1...20 {
                Log.line("压力测试第 \(n) 轮")
                RoundTrip.shared.hideFirstForeignItem()
                try? await Task.sleep(for: .milliseconds(400))
                RoundTrip.shared.restoreHidden()
                try? await Task.sleep(for: .milliseconds(400))
            }
            Log.line("压力测试完成：20 轮全部通过")
        }
    }
}
