// SectionSpacers.swift — BarShelfBackend
//
// Owns two of BarShelf's OWN NSStatusItems that act as structural dividers in the
// macOS menu bar:
//
//   • `boundary` — a near-zero-width (1 pt) empty marker whose minX is the dividing
//     line between the "visible" region and the "shelf" region. TahoeBackend (T7)
//     reads `boundaryMinX` to compute ⌘-drag destinations.
//
//   • `spacer` — a width-controllable empty NSStatusItem. When the shelf is hidden
//     (`setShelfHidden(true)`) its length is set to a large value (~10 000 pt) so that
//     items positioned to its left are pushed off the visible bar. When shown,
//     its length is reset to a minimal value so they return.
//
// Items are classified as "shelf vs visible" by being ⌘-dragged (CmdDragMover, T7)
// to the left or right of `boundaryMinX`. SectionSpacers only owns the dividers; it
// does not move foreign status-items.
//
// Swift 6 concurrency:
//   • @MainActor throughout (NSStatusBar/NSStatusItem are AppKit).
//   • `nonisolated(unsafe)` on stored properties accessed in `deinit` — deinit is
//     nonisolated in Swift 6; the properties are only written on @MainActor, and deinit
//     runs after the last reference is dropped (also on @MainActor in practice for
//     main-actor types), so the access is safe in practice.
//   • No global mutable state.

import AppKit

// MARK: - SectionSpacers

/// Owns the two structural ``NSStatusItem``s that BarShelf inserts into the menu bar
/// to divide visible items from shelved items.
@MainActor
public final class SectionSpacers {

    // MARK: Constants

    /// Length written to `spacer` when the shelf is hidden, large enough to push all
    /// items to spacer's left off the visible portion of the bar.
    public static let hiddenSpacerLength: CGFloat = 10_000

    // MARK: Private state

    // `nonisolated(unsafe)` permits access from the nonisolated `deinit`.
    // Both properties are only mutated on @MainActor; deinit is the sole reader outside
    // that context and runs after the last strong reference is released.
    nonisolated(unsafe) private var boundary: NSStatusItem?
    nonisolated(unsafe) private var spacer: NSStatusItem?

    // MARK: Lifecycle

    public init() {}

    deinit {
        if let b = boundary { NSStatusBar.system.removeStatusItem(b) }
        if let s = spacer   { NSStatusBar.system.removeStatusItem(s) }
    }

    // MARK: Public API

    /// Create and install `boundary` and `spacer` status items.
    ///
    /// Idempotent — calling `install()` more than once is a no-op after the first call.
    public func install() {
        guard boundary == nil else { return }  // idempotent

        // boundary: 1 pt wide, empty title — serves purely as a coordinate marker.
        let b = NSStatusBar.system.statusItem(withLength: 1)
        b.button?.title = ""
        b.button?.isEnabled = false
        boundary = b

        // spacer: starts at minimal length (bar is shown at launch).
        let s = NSStatusBar.system.statusItem(withLength: 1)
        s.button?.title = ""
        s.button?.isEnabled = false
        spacer = s
    }

    /// Toggle the shelf visibility by adjusting the spacer's length.
    ///
    /// - Parameter hidden: When `true`, set spacer length to `hiddenSpacerLength`
    ///   (pushes shelved items off-screen left). When `false`, set to
    ///   `NSStatusItem.variableLength` so items return to their natural positions.
    public func setShelfHidden(_ hidden: Bool) {
        guard let s = spacer else { return }
        s.length = hidden ? Self.hiddenSpacerLength : NSStatusItem.variableLength
    }

    /// The global-coordinate left edge of the `boundary` status item's button window.
    ///
    /// `TahoeBackend` (T7) reads this value to compute the ⌘-drag destination for
    /// items being moved between the visible and shelf regions.
    ///
    /// Returns `nil` if `install()` has not yet been called or the window is not yet on screen.
    public var boundaryMinX: CGFloat? {
        boundary?.button?.window?.frame.minX
    }

    /// Remove both status items from the menu bar and nil the references.
    ///
    /// Safe to call multiple times.
    public func teardown() {
        if let b = boundary {
            NSStatusBar.system.removeStatusItem(b)
            boundary = nil
        }
        if let s = spacer {
            NSStatusBar.system.removeStatusItem(s)
            spacer = nil
        }
    }
}
