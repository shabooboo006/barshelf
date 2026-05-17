// TahoeBackend.swift — BarShelfBackend
//
// Assembles the verified Plan 2B units behind the `MenuBarBackend` protocol seam.
//
// MECHANIC VERIFIED on-device macOS 26.4 Tahoe 2026-05-17 (CmdDragMover spike).
// Re-verify on each macOS major release (Risk Register #1).
//
// Architecture:
//   • DisplayScanner  — enumerates menu-bar status-layer windows (Screen Recording).
//   • SectionSpacers  — owns the boundary + spacer NSStatusItems; drives shelf visibility.
//   • CmdDragMover    — synthesizes ⌘-drag to reposition a foreign status-item window.
//   • MenuBarChangeObserver — fires a coalesced callback when bar content may have changed.
//
// Side-table (`table`):
//   Populated on each `enumerateStatusItems()` call, maps StableItemID → (wid, pid, bounds,
//   displayID). The table is NEVER persisted; wid is valid only for the current run and may
//   be recycled by the OS (Control Center recycles wid silently — see MenuBarChangeObserver).
//
// Swift 6 concurrency:
//   • `@MainActor` throughout — all units are @MainActor; protocol methods called from
//     @MainActor contexts (ShelfController, StatusItemRegistry, App entrypoint in T8).
//   • Protocol `MenuBarBackend` is not itself @MainActor, so conformance methods carry
//     implicit @MainActor isolation from the class annotation. The protocol is used only
//     from @MainActor call-sites in the 2B/core plan, so there is no actor-isolation
//     conflict in practice.
//   • `captureIcon(for:)` is synchronous per protocol (`-> Data?`) — deferred; see below.
//   • `nonisolated(unsafe)` is NOT needed here: deinit uses only the two stored objects
//     (spacers, changeObserver) and calls their public teardown/stop on @MainActor via
//     a captured reference; the actual storage is in those objects (which already use
//     nonisolated(unsafe) for their own deinit safety).

import AppKit
import BarShelfCore

// MARK: - TahoeBackend

/// `MenuBarBackend` implementation for macOS 26 Tahoe.
///
/// Assembles `DisplayScanner`, `SectionSpacers`, `CmdDragMover`, and
/// `MenuBarChangeObserver` into a single backend conformer.
///
/// **Verified on macOS 26.4 Tahoe 2026-05-17.** Re-verify on each macOS major release
/// (Risk Register #1 — the ⌘-drag relocate mechanic is historically the first thing
/// Bartender-class apps break on after an OS update).
@MainActor
public final class TahoeBackend: @MainActor MenuBarBackend {

    // MARK: Stored objects

    private let spacers = SectionSpacers()
    private let changeObserver = MenuBarChangeObserver()

    /// Cached side-table from the most recent `enumerateStatusItems()` call.
    ///
    /// Maps `StableItemID → (wid, pid, bounds, displayID)`.
    /// **Never persisted between launches** — wid values are ephemeral (the OS, especially
    /// Control Center, recycles them silently). The table is refreshed on every
    /// `enumerateStatusItems()` call; `move(_:to:)` reads it and falls back safely to a
    /// no-op when the entry is missing.
    private var table: [StableItemID: (wid: UInt32, pid: pid_t, bounds: CGRect, displayID: UInt32)] = [:]

    // MARK: Lifecycle

    public init() {
        spacers.install()
    }

    deinit {
        // Both teardown/stop are safe to call in deinit for their respective types.
        // SectionSpacers.deinit already removes the NSStatusItems, but calling teardown()
        // here is a clean explicit teardown path in case the caller wants deterministic
        // removal without waiting for deallocation.
        //
        // Swift 6 note: deinit is nonisolated. SectionSpacers and MenuBarChangeObserver
        // use nonisolated(unsafe) storage in their own deinits for NSStatusItem /
        // notification-token cleanup; we do NOT call their methods here from a nonisolated
        // context (that would be a data-race). Their own deinits handle cleanup automatically.
        // If a caller needs deterministic early teardown, they should call `teardown()` on
        // the @MainActor before releasing the last reference.
    }

    // MARK: Explicit teardown

    /// Deterministically remove BarShelf's structural spacer items from the menu bar
    /// and stop the change observer. Safe to call multiple times.
    ///
    /// Prefer calling this on the @MainActor before the last reference is released when
    /// deterministic cleanup ordering matters (e.g. app termination).
    public func teardown() {
        spacers.teardown()
        changeObserver.stop()
    }

    // MARK: - MenuBarBackend conformance

    /// Enumerate all on-screen status-layer windows on the largest-area display.
    ///
    /// Refreshes the internal side-table on each call. Callers (StatusItemRegistry)
    /// should drive re-enumeration via `observeChanges(_:)` rather than polling.
    public func enumerateStatusItems() -> [ItemSnapshot] {
        let result = DisplayScanner.enumerate()
        table = result.table
        return result.items
    }

    /// Move a status-item window to the specified `Placement` using an Ice-style ⌘-drag.
    ///
    /// Destination X is computed relative to `SectionSpacers.boundaryMinX`:
    ///   • `.shelf`   → 4 pt **left** of the boundary (items positioned here are hidden
    ///     when the spacer expands to its full off-screen length).
    ///   • `.visible` → 4 pt **right** of the boundary (items remain visible).
    ///
    /// If the item's `StableItemID` is not in the current side-table (i.e., the table has
    /// not yet been refreshed after a bar change, or the item is immovable/unknown), the
    /// call is a no-op — the safe default (never hide an item we cannot re-identify, per
    /// Risk Register #2).
    ///
    /// `CmdDragMover.move` returns a best-effort success flag; if it returns `false`,
    /// `StatusItemRegistry` (T5) will reconcile on the next enumeration cycle.
    public func move(_ id: StableItemID, to placement: Placement) {
        guard let entry = table[id] else {
            // Safe default: if the item is not in the current table, do nothing.
            // The next enumerateStatusItems() cycle will re-populate the table.
            return
        }

        // Compute destination X relative to the boundary divider.
        // Fall back to the item's own minX if the boundary is not yet on screen.
        let b = spacers.boundaryMinX ?? entry.bounds.minX
        let toX: CGFloat
        switch placement {
        case .shelf:
            toX = b - 4   // Just LEFT of the boundary → shelved region
        case .visible:
            toX = b + 4   // Just RIGHT of the boundary → visible region
        }

        let barY = entry.bounds.midY

        // Best-effort ⌘-drag. Result is informational; Registry reconciles on next cycle.
        _ = CmdDragMover.move(wid: entry.wid, pid: entry.pid, toX: toX, barY: barY)
    }

    /// Toggle the shelf visibility by adjusting the spacer NSStatusItem's length.
    ///
    /// Delegates directly to `SectionSpacers.setShelfHidden(_:)`.
    public func setShelfHidden(_ hidden: Bool) {
        spacers.setShelfHidden(hidden)
    }

    /// Returns `nil` — synchronous icon capture is deferred to Plan 2C.
    ///
    /// The protocol requires a synchronous `-> Data?` signature; on-demand bitmap capture
    /// via `IconCapturer.capture(wid:)` (async/throws, ScreenCaptureKit) will be wired
    /// to the BarShelf Bar UI in Plan 2C, where it can be called from an async context.
    /// Returning `nil` here is the safe fallback: the Bar UI in 2C will handle the nil
    /// case by displaying a placeholder until the async capture completes.
    public func captureIcon(for id: StableItemID) -> Data? {
        // Deferred: `IconCapturer.capture(wid:)` (async throws) is the intended impl;
        // wired to the BarShelf Bar UI in Plan 2C from an async context.
        return nil
    }

    /// Start observing menu-bar content changes.
    ///
    /// `MenuBarChangeObserver` coalesces app-activation notifications and a 2 s periodic
    /// timer into a single debounced callback. The callback should trigger a
    /// re-enumeration via `enumerateStatusItems()` (driven by StatusItemRegistry in T5).
    ///
    /// Subsequent calls replace the previous callback.
    public func observeChanges(_ onChange: @escaping () -> Void) {
        changeObserver.start {
            // MenuBarChangeObserver fires on @MainActor; protocol callback is non-isolated
            // (@escaping () -> Void). Capture safely — the call here IS on @MainActor
            // because changeObserver.start delivers its block on MainActor. Calling a
            // non-isolated closure from @MainActor is safe in Swift 6.
            onChange()
        }
    }
}
