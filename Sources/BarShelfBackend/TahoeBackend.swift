// TahoeBackend.swift — BarShelfBackend
//
// Assembles the verified Plan 2B units behind the `MenuBarBackend` protocol seam.
//
// MECHANIC VERIFIED on-device macOS 26.4 Tahoe 2026-05-17 (CmdDragMover spike).
// Re-verify on each macOS major release (Risk Register #1).
//
// HIDE MECHANIC (rc3): a 收进架 item is hidden by ⌘-dragging it OFF-SCREEN
// (MenuBarGeometry.shelfX) and restored by ⌘-dragging it back. There is NO
// spacer-collapse — the previous 10 000 pt `SectionSpacers` spacer pushed
// BarShelf's OWN menu-bar icon off-screen on real hardware (rc2 Central Risk #4,
// product-owner decision 2026-05-18 to replace it with per-item ⌘-drag).
//
// Architecture:
//   • DisplayScanner  — enumerates menu-bar status-layer windows (Screen Recording),
//     excluding BarShelf's own windows (pid != selfPID).
//   • MenuBarGeometry — pure off-screen / visible X math (unit-tested).
//   • CmdDragMover    — synthesizes ⌘-drag to reposition a foreign status-item window.
//   • MenuBarChangeObserver — fires a coalesced callback when bar content may change.
//
// Side-table (`table`):
//   Refreshed on each `enumerateStatusItems()` call: StableItemID → (wid, pid,
//   bounds, displayID). NEVER persisted; wid is valid only for the current run.
//
// Parked-items map (`parked`):
//   A hidden item is off the visible bar so it no longer enumerates and drops out
//   of `table`. `parked` retains its (wid, pid, displayID, lastVisibleMinX, barY)
//   so a later `move(_, .visible)` can ⌘-drag it back. CLAUDE.md: never hide an
//   item the user cannot get back.
//
// Swift 6 concurrency: @MainActor throughout; protocol methods called from
// @MainActor call-sites (ShelfController/registry/app entrypoint).

import AppKit
import CoreGraphics
import BarShelfCore

// MARK: - TahoeBackend

/// `MenuBarBackend` implementation for macOS 26 Tahoe.
///
/// **Verified on macOS 26.4 Tahoe.** Re-verify on each macOS major release
/// (Risk Register #1 — the ⌘-drag relocate mechanic is historically the first
/// thing Bartender-class apps break on after an OS update).
@MainActor
public final class TahoeBackend: @MainActor MenuBarBackend {

    // MARK: Stored objects

    private let changeObserver = MenuBarChangeObserver()

    /// Cached side-table from the most recent `enumerateStatusItems()` call.
    /// `StableItemID → (wid, pid, bounds, displayID)`. Never persisted.
    private var table: [StableItemID: (wid: UInt32, pid: pid_t, bounds: CGRect, displayID: UInt32)] = [:]

    /// Items currently parked off-screen (hidden). Retained across enumerations
    /// so a later restore can ⌘-drag them back to a visible anchor.
    private var parked: [StableItemID: (wid: UInt32, pid: pid_t, displayID: UInt32, lastVisibleMinX: CGFloat, barY: CGFloat)] = [:]

    // MARK: Lifecycle

    public init() {}

    deinit {
        // changeObserver uses nonisolated(unsafe) storage in its own deinit for
        // notification-token cleanup. We do not touch it from this nonisolated
        // deinit (that would be a data-race); its own deinit handles cleanup.
        // For deterministic early teardown, call `teardown()` on @MainActor.
    }

    // MARK: Explicit teardown

    /// Stop the change observer. Safe to call multiple times. (No structural
    /// status items are owned anymore — the spacer/boundary were removed.)
    public func teardown() {
        changeObserver.stop()
    }

    // MARK: - MenuBarBackend conformance

    /// Enumerate all on-screen status-layer windows on the largest-area display
    /// (BarShelf's own windows excluded by DisplayScanner). Refreshes `table`.
    public func enumerateStatusItems() -> [ItemSnapshot] {
        let result = DisplayScanner.enumerate()
        table = result.table
        return result.items
    }

    /// Move a status-item window on/off the visible bar via an Ice-style ⌘-drag.
    ///
    ///   • `.shelf`   → ⌘-drag to `MenuBarGeometry.shelfX` (off-screen left); the
    ///     item then drops out of enumeration. Its identity is retained in
    ///     `parked` so it can be restored.
    ///   • `.visible` → ⌘-drag back to `MenuBarGeometry.visibleX`. The source
    ///     entry is `table` (still live) or `parked` (was hidden).
    ///
    /// No-op (safe default — never lose an item we cannot re-identify, Risk
    /// Register #2) if the item is in neither map.
    public func move(_ id: StableItemID, to placement: Placement) {
        switch placement {
        case .shelf:
            guard let entry = table[id] else { return }      // must be live to shelve
            let display = CGDisplayBounds(entry.displayID)
            let toX = MenuBarGeometry.shelfX(displayBounds: display)
            let barY = entry.bounds.midY
            _ = CmdDragMover.move(wid: entry.wid, pid: entry.pid, toX: toX, barY: barY)
            // Retain identity + last visible position for a future restore.
            parked[id] = (wid: entry.wid, pid: entry.pid, displayID: entry.displayID,
                          lastVisibleMinX: entry.bounds.minX, barY: barY)

        case .visible:
            if let entry = table[id] {
                // Already live/visible position known — re-anchor if needed.
                let display = CGDisplayBounds(entry.displayID)
                let toX = MenuBarGeometry.visibleX(displayBounds: display,
                                                   lastItemMinX: entry.bounds.minX)
                _ = CmdDragMover.move(wid: entry.wid, pid: entry.pid,
                                      toX: toX, barY: entry.bounds.midY)
                parked[id] = nil
            } else if let p = parked[id] {
                // Restore a previously hidden item.
                let display = CGDisplayBounds(p.displayID)
                let toX = MenuBarGeometry.visibleX(displayBounds: display,
                                                   lastItemMinX: p.lastVisibleMinX)
                _ = CmdDragMover.move(wid: p.wid, pid: p.pid, toX: toX, barY: p.barY)
                parked[id] = nil
            }
            // else: unknown id → no-op (safe default).
        }
    }

    /// Returns `nil` — synchronous icon capture is deferred (protocol requires a
    /// synchronous `-> Data?`; on-demand `IconCapturer.capture` is async).
    public func captureIcon(for id: StableItemID) -> Data? { nil }

    /// Start observing menu-bar content changes (coalesced callback).
    public func observeChanges(_ onChange: @escaping () -> Void) {
        changeObserver.start { onChange() }
    }
}
