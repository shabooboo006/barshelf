// AppMenu.swift — BarShelf
//
// Manages the BarShelf status-item interaction:
//   • Plain left-click  → onToggle() (toggle shelf expanded/collapsed)
//   • Right-click or ctrl+left-click → transient popUp menu (settings, launch-at-login, quit)
//
// Key constraint: statusItem.menu is NEVER set persistently.
// Setting it permanently hijacks left-click and suppresses button.action.
// We use the popUp(positioning:at:in:) approach for the context menu instead.

import AppKit
import BarShelfUIKit

// MARK: - AppMenu

@MainActor
final class AppMenu: NSObject {

    // Retained references set during attach(to:…)
    private weak var statusItem: NSStatusItem?
    private var onToggle: (@MainActor () -> Void)?
    private var onSettings: (@MainActor () -> Void)?
    private var launch: LaunchAtLoginController?

    // MARK: - Public API

    func attach(
        to statusItem: NSStatusItem,
        onToggle: @escaping @MainActor () -> Void,
        onSettings: @escaping @MainActor () -> Void,
        launch: LaunchAtLoginController
    ) {
        self.statusItem = statusItem
        self.onToggle   = onToggle
        self.onSettings = onSettings
        self.launch     = launch

        // Do NOT set statusItem.menu — that would hijack left-click.
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    // MARK: - Click handler

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        let isRightClick = event.type == .rightMouseUp
        let isCtrlClick  = event.type == .leftMouseUp && event.modifierFlags.contains(.control)

        if isRightClick || isCtrlClick {
            showContextMenu(from: sender)
        } else {
            onToggle?()
        }
    }

    // MARK: - Context menu

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        // 设置…
        let settingsItem = NSMenuItem(
            title: "设置…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        // 开机自启 (checkbox)
        let launchItem = NSMenuItem(
            title: "开机自启",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.state = (launch?.isEnabled == true) ? .on : .off
        menu.addItem(launchItem)

        menu.addItem(.separator())

        // 退出
        let quitItem = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        // Present at the bottom edge of the status bar button (menu opens downward).
        let origin = NSPoint(x: 0, y: button.bounds.height)
        menu.popUp(positioning: nil, at: origin, in: button)
    }

    // MARK: - Menu actions

    @objc private func openSettings() {
        onSettings?()
    }

    @objc private func toggleLaunchAtLogin() {
        guard let launch else { return }
        launch.setEnabled(!launch.isEnabled)
    }
}
