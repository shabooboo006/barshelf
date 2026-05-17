// main.swift — BarShelf live agent (T8)
//
// Wires TahoeBackend → ShelfController → diff-based moves end-to-end.
// Safe default: reconcile/desiredVisibility force immovable/ambiguous → .visible;
// no additional hiding logic here.
//
// Debug menu (required for T9 H2 gate): per-item submenu to set 常显/收进架/激活时显示.

import AppKit
import BarShelfCore
import BarShelfBackend

// MARK: - AppController

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate {

    // MARK: Core components

    private let backend = TahoeBackend()
    private let store   = ClassificationStore(kv: UserDefaultsKV())
    private let registry = StatusItemRegistry()
    private let activeApp = ActiveAppMonitor()

    // MARK: BarShelf's own status item

    private var statusItem: NSStatusItem!

    // MARK: State

    private var expanded = false
    private var lastPlacement: [StableItemID: Placement] = [:]

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install BarShelf's own menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "▣"
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp])
        }

        // Attach a menu for right-click / alternate access; delegate keeps it fresh
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        // Start observers
        activeApp.start { [weak self] _ in
            self?.recompute()
        }
        backend.observeChanges { [weak self] in
            self?.recompute()
        }

        // Initial computation
        recompute()
    }

    func applicationWillTerminate(_ notification: Notification) {
        backend.teardown()
    }

    // MARK: Status item click (left-click → toggle expanded)

    @objc private func statusItemClicked() {
        expanded.toggle()
        recompute()
    }

    // MARK: Core recompute

    private func recompute() {
        let items  = backend.enumerateStatusItems()
        let states = registry.reconcile(live: items, stored: store.all())
        let want   = ShelfController.desiredVisibility(
            states: states,
            live: items,
            frontmost: activeApp.frontmostBundleID,
            expanded: expanded
        )
        let diff = ShelfController.changes(from: lastPlacement, to: want)
        for (id, placement) in diff {
            backend.move(id, to: placement)
        }
        backend.setShelfHidden(!expanded)
        lastPlacement = want
    }

    // MARK: NSMenuDelegate — rebuild debug menu each open

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        // --- Per-item section ---
        let items = backend.enumerateStatusItems()
        if items.isEmpty {
            let none = NSMenuItem(title: "(no items detected)", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        } else {
            for snapshot in items {
                let id = snapshot.id
                let label = id.bundleID.isEmpty ? "(unknown)" : id.bundleID
                let sub = NSMenu(title: label)

                let always = NSMenuItem(
                    title: "常显 (always visible)",
                    action: #selector(setAlwaysVisible(_:)),
                    keyEquivalent: ""
                )
                always.representedObject = id
                always.target = self

                let shelved = NSMenuItem(
                    title: "收进架 (shelved)",
                    action: #selector(setShelved(_:)),
                    keyEquivalent: ""
                )
                shelved.representedObject = id
                shelved.target = self

                let whenActive = NSMenuItem(
                    title: "激活时显示 (show when active)",
                    action: #selector(setShowWhenActive(_:)),
                    keyEquivalent: ""
                )
                whenActive.representedObject = id
                whenActive.target = self

                // Checkmark current state
                let current = store.state(for: id) ?? .alwaysVisible
                always.state     = current == .alwaysVisible   ? .on : .off
                shelved.state    = current == .shelved          ? .on : .off
                whenActive.state = current == .showWhenActive   ? .on : .off

                sub.addItem(always)
                sub.addItem(shelved)
                sub.addItem(whenActive)

                let parent = NSMenuItem(title: label, action: nil, keyEquivalent: "")
                parent.submenu = sub
                if snapshot.isImmovable {
                    parent.isEnabled = false   // immovable items can't be classified
                }
                menu.addItem(parent)
            }
        }

        menu.addItem(.separator())

        // --- Toggle expanded ---
        let toggleTitle = expanded ? "收起 BarShelf (collapse)" : "展开/收起 (toggle expanded)"
        let toggle = NSMenuItem(
            title: toggleTitle,
            action: #selector(toggleExpanded),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        menu.addItem(.separator())

        // --- Quit ---
        let quit = NSMenuItem(
            title: "退出",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)
    }

    // MARK: State-setting actions

    @objc private func setAlwaysVisible(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? StableItemID else { return }
        store.set(.alwaysVisible, for: id)
        recompute()
    }

    @objc private func setShelved(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? StableItemID else { return }
        store.set(.shelved, for: id)
        recompute()
    }

    @objc private func setShowWhenActive(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? StableItemID else { return }
        store.set(.showWhenActive, for: id)
        recompute()
    }

    @objc private func toggleExpanded() {
        expanded.toggle()
        recompute()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // LSUIElement agent — no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
