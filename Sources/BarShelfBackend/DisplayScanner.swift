// DisplayScanner.swift — BarShelfBackend
//
// Verified filter logic ported from spike/Sources/BarShelfSpike/MenuBarScan.swift,
// confirmed on macOS 26.4 on a 3-display rig (commit ff6c546 spike branch).
//
// Two-level design:
//   • classify(_:displays:statusLayer:) — PURE, no system calls, fully unit-tested.
//   • enumerate()                       — live wrapper; calls system APIs; @MainActor.
//
// CONCERN (deferred to T3/AX work): StableItemID.titleKey is always "" here —
// the AX-title heuristic requires Accessibility API and is out of scope for V0-2B T2.
// Registry (T5) must handle identity collisions that arise from titleKey="".
//
// CONCERN (noted): if two live items resolve to the same StableItemID, the side-table
// last-writer-wins (dictionary key collision). Deduplication/disambiguation is Registry's
// responsibility (T5), not DisplayScanner's.

@preconcurrency import CoreGraphics
import AppKit
import BarShelfCore

// MARK: - Plain input types (used by the pure classify function and by tests)

/// Geometry + metadata for one CGWindow entry, extracted from the CGWindowList dict.
/// All fields are value types so classify() is trivially pure and test-friendly.
public struct RawWindow: Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let w: CGFloat
    public let h: CGFloat
    public let layer: Int
    public let ownerPID: pid_t
    public let ownerName: String
    public let wid: UInt32

    public init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat,
                layer: Int, ownerPID: pid_t, ownerName: String, wid: UInt32) {
        self.x = x; self.y = y; self.w = w; self.h = h
        self.layer = layer; self.ownerPID = ownerPID
        self.ownerName = ownerName; self.wid = wid
    }
}

/// One display's identity and global-coordinate bounding rectangle.
public struct DisplayRect: Sendable {
    public let id: UInt32
    public let bounds: CGRect

    public init(id: UInt32, bounds: CGRect) {
        self.id = id; self.bounds = bounds
    }
}

// MARK: - DisplayScanner

/// Enumerates and classifies menu-bar status-layer windows.
public enum DisplayScanner {

    // MARK: Pure predicate (no system calls — fully unit-tested)

    /// Classify one `RawWindow` against a set of known displays.
    ///
    /// Target display = the largest-area one (mirrors the verified spike logic).
    ///
    /// Belongs criteria (all must hold):
    ///   1. layer == statusLayer
    ///   2. x > -5000  (excludes our own parked/off-screen items)
    ///   3. midX ∈ [target.minX, target.maxX)  (half-open — sits on THIS display)
    ///   4. y ∈ [target.minY - 2, target.minY + 44]  (menu bar band ± 2 px slop)
    ///   5. h ∈ [18, 44]  (sane status-bar item height)
    ///
    /// Immovable if: belongs AND ownerName ∈ {"Control Center","BentoBox"} AND w >= 120
    /// (the cluster-panel heuristic from the spike).
    public static func classify(
        _ win: RawWindow,
        displays: [DisplayRect],
        statusLayer: Int
    ) -> (belongs: Bool, displayID: UInt32?, immovable: Bool) {

        // Step 1: pick target display (largest by area).
        guard let target = displays.max(by: { a, b in
            a.bounds.width * a.bounds.height < b.bounds.width * b.bounds.height
        }) else {
            return (false, nil, false)
        }

        let t = target.bounds
        let midX = win.x + win.w / 2.0

        // Step 2: apply the verified spike filter in order.
        guard win.layer == statusLayer,
              win.x > -5000,
              midX >= t.minX, midX < t.maxX,
              win.y >= t.minY - 2, win.y <= t.minY + 44,
              win.h >= 18, win.h <= 44
        else {
            return (false, nil, false)
        }

        // Step 3: immovable heuristic — Control Center / BentoBox wide cluster panel.
        let immovable = (win.ownerName == "Control Center" || win.ownerName == "BentoBox")
                     && win.w >= 120

        return (true, target.id, immovable)
    }

    // MARK: Live enumerate (system APIs — @MainActor, NOT unit-tested; verified at T9)

    /// Enumerate all on-screen status-layer windows on the largest-area display.
    ///
    /// Returns:
    ///   • `items`  — `[ItemSnapshot]` suitable for `MenuBarBackend.enumerateStatusItems()`
    ///   • `table`  — side-table mapping `StableItemID → (wid, pid, bounds, displayID)` for
    ///     move/click operations in later tasks.
    ///
    /// - Note: Screen Recording permission is required; called only after PermissionsManager
    ///   confirms it is granted.
    @MainActor
    public static func enumerate() -> (
        items: [ItemSnapshot],
        table: [StableItemID: (wid: UInt32, pid: pid_t, bounds: CGRect, displayID: UInt32)]
    ) {
        // 1. Collect active displays.
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(16, &displayIDs, &displayCount)
        let displays: [DisplayRect] = (0..<Int(displayCount)).map { i in
            DisplayRect(id: displayIDs[i], bounds: CGDisplayBounds(displayIDs[i]))
        }

        // 2. Determine the status window layer.
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow))

        // 3. Query on-screen windows.
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return ([], [:])
        }

        // 4. Our own PID — exclude BarShelf's own windows.
        let selfPID = getpid()

        var items: [ItemSnapshot] = []
        var table: [StableItemID: (wid: UInt32, pid: pid_t, bounds: CGRect, displayID: UInt32)] = [:]

        for entry in infoList {
            // Extract required fields.
            guard
                let layer     = entry[kCGWindowLayer as String] as? Int,
                let pid       = entry[kCGWindowOwnerPID as String] as? pid_t,
                let wid       = entry[kCGWindowNumber as String] as? UInt32,
                let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
                let ex        = boundsDict["X"],
                let ey        = boundsDict["Y"],
                let ew        = boundsDict["Width"],
                let eh        = boundsDict["Height"],
                pid != selfPID
            else { continue }

            let ownerName = (entry[kCGWindowOwnerName as String] as? String) ?? "pid \(pid)"

            let raw = RawWindow(
                x: ex, y: ey, w: ew, h: eh,
                layer: layer,
                ownerPID: pid,
                ownerName: ownerName,
                wid: wid
            )

            let (belongs, displayID, immovable) = classify(raw, displays: displays, statusLayer: statusLayer)
            guard belongs, let dID = displayID else { continue }

            // Build a best-effort stable identity.
            // titleKey = "" because AX-title lookup requires Accessibility permission;
            // deferred to T3. Registry (T5) handles collision from titleKey="".
            let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                        ?? "pid \(pid)"
            let stableID = StableItemID(bundleID: bundleID, titleKey: "")

            let bounds = CGRect(x: ex, y: ey, width: ew, height: eh)
            let snapshot = ItemSnapshot(id: stableID, displayID: dID, isImmovable: immovable)

            items.append(snapshot)
            // Note: last-wins on table key collision (same bundleID + "" titleKey).
            // Disambiguation is Registry's responsibility (T5).
            table[stableID] = (wid: wid, pid: pid, bounds: bounds, displayID: dID)
        }

        return (items, table)
    }
}
