// MenuBarChangeObserver.swift — BarShelfBackend
//
// Triggers re-enumeration of menu bar items when the set of status items may have changed.
//
// Two trigger sources (both required for reliability):
//
//   1. NSWorkspace.didActivateApplicationNotification — app switches frequently cause
//      status items to appear/disappear (e.g. "show when active" items from other apps,
//      or apps that lazily create/destroy their NSStatusItem on focus change).
//
//   2. Debounced periodic re-scan (~2 s repeating Timer) — Control Center and system
//      agents recycle CGWindowIDs without posting any notification, so a periodic
//      reconcile is needed to stay in sync.
//
// Coalescing: multiple rapid triggers within the debounce window produce a single
// onChange callback to avoid flooding the backend with redundant enumerations.
//
// Swift 6 concurrency:
//   • @MainActor throughout — Timer runs on the main run loop; NSWorkspace callbacks
//     are dispatched to .main queue; onChange is @MainActor.
//   • Notification/Timer blocks use `MainActor.assumeIsolated` to assert the
//     main-thread dispatch invariant to the Swift 6 type-checker.
//   • `nonisolated(unsafe)` on the observer token allows deinit to remove it safely.
//   • No global mutable state.

import AppKit

// MARK: - MenuBarChangeObserver

/// Fires a coalesced `onChange` callback when the menu bar's set of status items
/// may have changed, combining app-activation notifications with a periodic re-scan.
@MainActor
public final class MenuBarChangeObserver {

    // MARK: Constants

    /// Debounce window: a pending onChange call is held for this duration before firing,
    /// so that rapid successive triggers (e.g. app switch + timer near-coincidence) are
    /// coalesced into one callback.
    private static let debounceInterval: TimeInterval = 0.25

    /// Period of the periodic re-scan timer. Control Center can recycle window IDs
    /// silently; a 2 s period balances freshness vs. overhead.
    private static let timerPeriod: TimeInterval = 2.0

    // MARK: Private state

    // `nonisolated(unsafe)` permits access from nonisolated `deinit`.
    // Written only on @MainActor; deinit is the sole reader outside that context.
    nonisolated(unsafe) private var notificationToken: (any NSObjectProtocol)?

    private var periodicTimer: Timer?
    private var debounceTask: Task<Void, Never>?
    private var onChangeHandler: (@MainActor () -> Void)?

    // MARK: Lifecycle

    public init() {}

    deinit {
        if let token = notificationToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    // MARK: Public API

    /// Start observing. Subsequent calls replace the previous callback.
    ///
    /// - Parameter onChange: Called on the main actor (coalesced) when the menu bar
    ///   content may have changed. Should trigger a re-enumeration via the backend.
    public func start(_ onChange: @escaping @MainActor () -> Void) {
        stop()
        onChangeHandler = onChange

        // --- Trigger 1: app-activation notifications ---
        // Dispatch to .main so the block can use assumeIsolated.
        notificationToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleChange()
            }
        }

        // --- Trigger 2: periodic timer ---
        // Timer fires on the main run loop (default mode) when added via scheduledTimer.
        periodicTimer = Timer.scheduledTimer(
            withTimeInterval: Self.timerPeriod,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.scheduleChange()
            }
        }
    }

    /// Stop observing and cancel any pending debounced callback. Safe to call when stopped.
    public func stop() {
        // Cancel debounce.
        debounceTask?.cancel()
        debounceTask = nil

        // Remove notification observer.
        if let token = notificationToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            notificationToken = nil
        }

        // Invalidate periodic timer.
        periodicTimer?.invalidate()
        periodicTimer = nil

        onChangeHandler = nil
    }

    // MARK: Private helpers

    /// Schedule a debounced onChange: cancel the previous pending task (if any) and
    /// create a new one that fires after `debounceInterval`. This coalesces multiple
    /// rapid triggers into a single callback.
    private func scheduleChange() {
        debounceTask?.cancel()
        guard let handler = onChangeHandler else { return }
        debounceTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(Self.debounceInterval * 1_000_000_000))
                handler()
            } catch {
                // Task was cancelled (another trigger arrived within debounce window) — no-op.
            }
        }
    }
}
