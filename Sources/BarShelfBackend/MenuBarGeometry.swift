// MenuBarGeometry.swift — BarShelfBackend
//
// Pure X-coordinate math for the ⌘-drag hide mechanic. Replaces the unsound
// 10 000 pt spacer-collapse (rc2 Central-Risk regression: the spacer pushed
// BarShelf's OWN menu-bar icon off-screen). No system calls — fully unit-tested.
//
// MENU-BAR GEOMETRY VERIFIED on macOS 26.4 Tahoe (Risk Register #4 — re-verify
// each macOS major release; confine all such constants to this unit).

import CoreGraphics

public enum MenuBarGeometry {

    /// Off-screen X for a shelved item: far enough left of the target display
    /// that the item's midX is left of `displayBounds.minX`, so `DisplayScanner`
    /// no longer counts it as "on this display" (it drops out of enumeration =
    /// hidden). 400 pt exceeds any plausible status-item width; this stays well
    /// inside the `> -5000` self-park sentinel for all realistic display layouts,
    /// and even an exotic far-left display still yields a hidden item (it then
    /// trips DisplayScanner's `x > -5000` exclusion instead — hidden either way).
    public static func shelfX(displayBounds: CGRect) -> CGFloat {
        displayBounds.minX - 400
    }

    /// Visible-anchor X to restore an item. Reuse the item's last-known minX when
    /// it still falls within the display's horizontal range; otherwise fall back
    /// to a safe spot inside the menu-bar region (right side, where status items
    /// live). A stale shelved (off-screen) minX must never be reused.
    public static func visibleX(displayBounds: CGRect, lastItemMinX: CGFloat?) -> CGFloat {
        if let x = lastItemMinX, x >= displayBounds.minX, x < displayBounds.maxX {
            return x
        }
        return displayBounds.maxX - 300
    }
}
