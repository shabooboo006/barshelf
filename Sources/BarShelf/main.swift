// main.swift — BarShelf live agent (T7 integration)
//
// Wires PermissionsManager gate + Settings + onboarding + launch-at-login +
// real template icons into the live agent.
//
// Gate: PermissionsDecision.decide() at launch.
//   • NOT ready  → show onboarding window; block recompute pipeline.
//   • Ready      → enterReadyMode() → start TahoeBackend + ShelfController pipeline.
//
// The recompute() body is UNCHANGED from 2B (TahoeBackend + ShelfController +
// StatusItemRegistry + ActiveAppMonitor diff-based moves + setShelfHidden).
//
// AppMenu replaces the 2B debug NSMenu.
// SettingsScene (SwiftUI) replaces per-item debug state-setting.

import AppKit
import BarShelfCore
import BarShelfBackend
import BarShelfUIKit

// MARK: - AppController

@MainActor
final class AppController: NSObject, NSApplicationDelegate {

    // MARK: Core components (2B pipeline — unchanged)

    private let backend   = TahoeBackend()
    private let store     = ClassificationStore(kv: UserDefaultsKV())
    private let registry  = StatusItemRegistry()
    private let activeApp = ActiveAppMonitor()

    // MARK: Integration additions (T7)

    private let probe  = LivePermissionsProbe()
    private let launch = LaunchAtLoginController(service: SMAppServiceLoginItem())
    private let appMenu = AppMenu()

    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?

    // MARK: BarShelf's own status item

    private var statusItem: NSStatusItem!

    // MARK: State (2B — unchanged)

    private var expanded = false
    private var lastPlacement: [StableItemID: Placement] = [:]

    // MARK: NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Install BarShelf's own menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Set initial icon (collapsed state, attention look for onboarding)
        applyStatusIcon(collapsed: true)

        // Gate: check permissions before starting the pipeline
        let decision = PermissionsDecision.decide(ax: probe.axTrusted, screen: probe.screenGranted)
        if decision.isReady {
            enterReadyMode()
        } else {
            // Show onboarding; do NOT start the recompute pipeline
            let win = makeOnboardingWindow(
                probe: probe,
                onRecheck: { [weak self] in self?.reevaluateGate() },
                onContinue: { [weak self] in self?.enterReadyMode() }
            )
            onboardingWindow = win
            win.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        backend.teardown()
    }

    // MARK: Gate helpers

    /// Re-checks permissions (called from onboarding "重新检查" button).
    /// If now ready, closes onboarding and enters ready mode.
    /// If still not ready, leaves the onboarding window up reflecting fresh state.
    func reevaluateGate() {
        let decision = PermissionsDecision.decide(ax: probe.axTrusted, screen: probe.screenGranted)
        if decision.isReady {
            onboardingWindow?.close()
            onboardingWindow = nil
            enterReadyMode()
        }
        // else: onboarding stays open; the view will reflect fresh probe values on next render
    }

    /// Transitions the app from onboarding/gated mode into fully operational mode.
    /// Safe to call multiple times (idempotent: sets up AppMenu+pipeline only once).
    func enterReadyMode() {
        // Close onboarding if still open
        onboardingWindow?.close()
        onboardingWindow = nil

        // Apply correct template icon for current expanded state
        updateStatusIcon()

        // Wire AppMenu (replaces 2B debug NSMenu)
        appMenu.attach(
            to: statusItem,
            onToggle: { [weak self] in
                guard let self else { return }
                self.expanded.toggle()
                self.updateStatusIcon()
                self.recompute()
            },
            onSettings: { [weak self] in
                self?.openSettings()
            },
            launch: launch
        )

        // Start observers (2B pipeline)
        activeApp.start { [weak self] _ in
            self?.recompute()
        }
        backend.observeChanges { [weak self] in
            self?.recompute()
        }

        // Initial computation
        recompute()
    }

    // MARK: Status icon helpers

    /// Applies the collapsed or expanded template image, falling back to a text title.
    private func applyStatusIcon(collapsed: Bool) {
        let resourceName = collapsed ? "Resources/BarShelfCollapsedTemplate" : "Resources/BarShelfExpandedTemplate"
        if let url = Bundle.barshelfResources.url(forResource: resourceName, withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            statusItem.button?.image = img
            statusItem.button?.title = ""
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = "▣"
        }
    }

    /// Swaps the collapsed/expanded template image to reflect the current `expanded` state.
    func updateStatusIcon() {
        applyStatusIcon(collapsed: !expanded)
    }

    // MARK: Settings

    /// Lazily creates the settings window (once) and brings it to front.
    func openSettings() {
        if settingsWindow == nil {
            let model = SettingsModel(
                backend: backend,
                store: store,
                registry: registry,
                thumbnail: { _ in nil }   // real thumbnails deferred (2C-acceptable limitation)
            )
            settingsWindow = makeSettingsWindow(
                model: model,
                launchController: launch
            )
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: Core recompute (2B body — UNCHANGED)

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
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // LSUIElement agent — no Dock icon
let controller = AppController()
app.delegate = controller
app.run()
