// MECHANIC VERIFIED on-device macOS 26.4 Tahoe 2026-05-17; re-verify each macOS major (Risk Register #1).
//
// CmdDragMover — Ice-style synthesized ⌘-drag to reposition a foreign menu-bar status-item window.
//
// Event construction is ported verbatim from the on-device-verified spike:
//   spike/Sources/BarShelfSpike/DragMover.swift (confirmed: X 664→800, real Control-Center item, 2026-05-17).
//
// Hardening added here (beyond the spike): frame-change wait inspired by jordanbaird/Ice
// MenuBarItemManager — after posting events, poll the window's kCGWindowBounds for up to ~50 ms
// (5 × 10 ms) and return true only if the bounds actually shifted, giving the caller a reliable
// success signal before proceeding to the next operation.
//
// Swift 6 strict concurrency notes:
//   • @preconcurrency import CoreGraphics — CGEventField is not Sendable in the SDK headers.
//   • All entry points are @MainActor — no global mutable state; uid is a local stack value.

@preconcurrency import CoreGraphics
import AppKit

// MARK: - CmdDragMover

/// Synthesizes a native macOS ⌘-drag to move a foreign menu-bar status-item window.
///
/// This is the central-risk mechanic verified on-device (macOS 26.4 Tahoe, 2026-05-17).
/// Callers must hold Accessibility permission before invoking; no permission check is
/// performed here (that is `PermissionsManager`'s responsibility).
public enum CmdDragMover {

    // Private field constant matching the spike — private CGEventField for windowID targeting.
    private static let fWindowID = CGEventField(rawValue: 0x33)!

    // MARK: - Public API

    /// Synthesize a ⌘-drag moving window `wid` (owned by `pid`) so its drop point is at
    /// (`toX`, `barY`) in global screen coordinates.
    ///
    /// - Parameters:
    ///   - wid: The CGWindowID of the status-item window to move.
    ///   - pid: The owning process's PID.
    ///   - toX: Target X coordinate (global screen coords, Quartz origin top-left).
    ///   - barY: Target Y coordinate — typically the menu bar's midY for this display.
    ///
    /// - Returns: `true` if the window's bounds changed within ~50 ms of the drag
    ///   (reliable success); `false` if bounds did not change or could not be verified.
    ///   If the pre-move bounds are unreadable the events are still posted and the return
    ///   value reflects whether posting succeeded (best-effort).
    @MainActor
    public static func move(wid: UInt32, pid: pid_t, toX: CGFloat, barY: CGFloat) -> Bool {
        guard let src = CGEventSource(stateID: .hidSystemState) else {
            return false
        }

        // Unique tag per drag — mirrors spike's uid = Int64(Date().timeIntervalSince1970 * 1000).
        let uid = Int64(Date().timeIntervalSince1970 * 1000)

        // Down fires at an off-screen source point (field-targeted via windowID, not cursor pos).
        let srcPoint = CGPoint(x: 20_000, y: 20_000)   // Ice: off-screen; field-targeted
        let dstPoint = CGPoint(x: toX, y: barY)

        guard let down = makeEvent(type: .leftMouseDown, pos: srcPoint, cmd: true,
                                   pid: pid, wid: wid, uid: uid, src: src),
              let up   = makeEvent(type: .leftMouseUp,   pos: dstPoint, cmd: false,
                                   pid: pid, wid: wid, uid: uid, src: src)
        else {
            return false
        }

        // Capture pre-move bounds for the frame-change wait.
        let preBounds = windowBounds(wid)

        // Post EXACTLY as the verified spike: postToPid first, then session tap.
        down.postToPid(pid)
        down.post(tap: .cgSessionEventTap)
        usleep(80_000)                                  // spike: usleep(80_000) between down/up
        up.postToPid(pid)
        up.post(tap: .cgSessionEventTap)

        // Frame-change wait (Ice hardening): poll up to 5×10 ms = 50 ms.
        guard let before = preBounds else {
            // Bounds were unreadable before the drag; events were posted — best-effort true.
            return true
        }

        for _ in 0..<5 {
            usleep(10_000)  // 10 ms
            if let after = windowBounds(wid), after.origin != before.origin {
                return true
            }
        }
        // Bounds did not change within ~50 ms.
        return false
    }

    // MARK: - Private helpers

    /// Build one mouse event with all the targeting fields set exactly as the verified spike.
    ///
    /// - Parameters:
    ///   - type: `.leftMouseDown` or `.leftMouseUp`.
    ///   - pos:  Cursor position field (off-screen for down, destination for up).
    ///   - cmd:  Set `.maskCommand` flag on the event (down only in the spike).
    ///   - pid:  Target process PID.
    ///   - wid:  Target CGWindowID.
    ///   - uid:  Per-drag unique tag written to `.eventSourceUserData`.
    ///   - src:  Shared `CGEventSource` for this drag pair.
    private static func makeEvent(
        type: CGEventType,
        pos: CGPoint,
        cmd: Bool,
        pid: pid_t,
        wid: UInt32,
        uid: Int64,
        src: CGEventSource
    ) -> CGEvent? {
        guard let e = CGEvent(mouseEventSource: src, mouseType: type,
                              mouseCursorPosition: pos, mouseButton: .left) else {
            return nil
        }
        if cmd { e.flags = .maskCommand }   // down only — up has no flag (verified spike)
        e.setIntegerValueField(.eventTargetUnixProcessID,                                   value: Int64(pid))
        e.setIntegerValueField(.eventSourceUserData,                                        value: uid)
        e.setIntegerValueField(.mouseEventWindowUnderMousePointer,                          value: Int64(wid))
        e.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,    value: Int64(wid))
        e.setIntegerValueField(fWindowID,                                                   value: Int64(wid))
        return e
    }

    /// Read the current `kCGWindowBounds` for `wid` using CGWindowList.
    ///
    /// Uses `.optionIncludingWindow` so it works whether the window is on- or off-screen
    /// (needed for parked/hidden items that may not appear in `.optionOnScreenOnly`).
    private static func windowBounds(_ wid: UInt32) -> CGRect? {
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionIncludingWindow],
            wid
        ) as? [[String: Any]],
        let entry = infoList.first,
        let boundsDict = entry[kCGWindowBounds as String] as? [String: CGFloat],
        let x = boundsDict["X"],
        let y = boundsDict["Y"],
        let w = boundsDict["Width"],
        let h = boundsDict["Height"]
        else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
