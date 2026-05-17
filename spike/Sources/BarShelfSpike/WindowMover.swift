import CoreGraphics
import CSkyLight

enum WindowMover {
    static let offscreenPoint = CGPoint(x: -10_000, y: 0)

    /// Returns current CG bounds of a window id, or nil on failure.
    static func bounds(_ wid: UInt32) -> CGRect? {
        let cid = SLSMainConnectionID()
        var r = CGRect.zero
        let err = SLSGetWindowBounds(cid, wid, &r)
        if err != .success { Log.line("SLSGetWindowBounds 错误=\(err.rawValue)"); return nil }
        return r
    }

    /// Primary technique: SLSMoveWindow(point). Returns true on .success.
    static func move(_ wid: UInt32, to point: CGPoint) -> Bool {
        let cid = SLSMainConnectionID()
        var p = point
        let err = SLSMoveWindow(cid, wid, &p)
        Log.line("SLSMoveWindow 窗口=\(wid) -> \(point) 错误码=\(err.rawValue)")
        return err == .success
    }

    /// Fallback technique: SLSSetWindowFrame(frame). Used if move() proves ineffective.
    static func setFrame(_ wid: UInt32, _ frame: CGRect) -> Bool {
        let cid = SLSMainConnectionID()
        let err = SLSSetWindowFrame(cid, wid, frame)
        Log.line("SLSSetWindowFrame 窗口=\(wid) -> \(frame) 错误码=\(err.rawValue)")
        return err == .success
    }
}
