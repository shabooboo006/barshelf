// ActiveAppMonitor.swift — BarShelfBackend
//
// Tracks the frontmost application using NSWorkspace — ZERO permission required.
//
// Used by ShelfController to implement the "show when active" (激活时显示) state:
// when a shelved item's owning app becomes frontmost, the item should become visible.
//
// Swift 6 concurrency:
//   • @MainActor — NSWorkspace notification callbacks are dispatched to .main queue;
//     @MainActor guarantees isolation and satisfies the Swift 6 compiler.
//   • NotificationCenter observer block: the block is dispatched to OperationQueue.main
//     (main thread), so capturing `self` and calling @MainActor methods is safe.
//     We use `assumeIsolated` to assert the invariant to the Swift 6 type-checker.
//   • `nonisolated(unsafe)` on the observer token allows reading it from nonisolated
//     `deinit`; the token is only written on @MainActor and deinit is the sole
//     reader outside that context.
//   • No global mutable state.

import AppKit

// MARK: - ActiveAppMonitor

/// Observes `NSWorkspace.didActivateApplicationNotification` and surfaces the
/// frontmost app's bundle identifier.
///
/// No permissions are required; `NSWorkspace` frontmost-app observation is available
/// to all apps.
@MainActor
public final class ActiveAppMonitor {

    // MARK: Public state

    /// The bundle identifier of the currently frontmost application.
    ///
    /// Initialised from `NSWorkspace.shared.frontmostApplication` at construction time,
    /// then updated each time the frontmost app changes.
    public private(set) var frontmostBundleID: String

    // MARK: Private state

    // `nonisolated(unsafe)` permits access from nonisolated `deinit`.
    // Written only on @MainActor; deinit is the sole reader outside that context.
    nonisolated(unsafe) private var observerToken: (any NSObjectProtocol)?

    // MARK: Lifecycle

    public init() {
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? ""
    }

    deinit {
        if let token = observerToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    // MARK: Public API

    /// Start observing frontmost-app changes.
    ///
    /// - Parameter onChange: Called on the main actor whenever the frontmost app changes.
    ///   Receives the new bundle identifier (empty string if unavailable).
    ///
    /// Calling `start` again after it is already running replaces the previous callback.
    public func start(_ onChange: @escaping @MainActor (String) -> Void) {
        // Remove any previous observer.
        if let token = observerToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            observerToken = nil
        }

        // Dispatch to .main so we can use `assumeIsolated` in the block.
        observerToken = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Extract the bundle ID from the notification's userInfo before entering
            // the @MainActor context — this avoids sending the non-Sendable Notification
            // across the actor boundary (Swift 6 data race check).
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                        as? NSRunningApplication
            let bundleID = app?.bundleIdentifier ?? ""
            // The block is guaranteed to run on the main thread (queue: .main).
            // `assumeIsolated` asserts this invariant to the Swift 6 type-checker.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.frontmostBundleID = bundleID
                onChange(bundleID)
            }
        }
    }

    /// Stop observing. Safe to call when not started.
    public func stop() {
        if let token = observerToken {
            NSWorkspace.shared.notificationCenter.removeObserver(token)
            observerToken = nil
        }
    }
}
