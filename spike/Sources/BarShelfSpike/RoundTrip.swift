import AppKit
import CoreGraphics

@MainActor
final class RoundTrip {
    static let shared = RoundTrip()

    private var hidden: (item: ForeignStatusItem, originalCGBounds: CGRect)?

    func hideFirstForeignItem() {
        let items = MenuBarScan.shared.scan()
        guard let target = items.first else { Log.line("no foreign items"); return }
        guard let original = WindowMover.bounds(target.windowNumber) else {
            Log.line("could not read bounds; abort"); return
        }
        let ok = WindowMover.move(target.windowNumber, to: WindowMover.offscreenPoint)
        Log.line("hide \(target.ownerName) win=\(target.windowNumber) ok=\(ok)")
        if ok { hidden = (target, original) }
    }

    func restoreHidden() {
        guard let h = hidden else { Log.line("nothing hidden"); return }
        let ok = WindowMover.move(h.item.windowNumber, to: h.originalCGBounds.origin)
        Log.line("restore \(h.item.ownerName) ok=\(ok)")
        if ok { hidden = nil }
    }

    /// Restore the hidden item to a VISIBLE anchor, synthesize a visible click,
    /// wait, then move it back off-screen.
    func fullRoundTrip() {
        guard let h = hidden else { Log.line("nothing hidden; run Hide first"); return }
        let anchor = h.originalCGBounds // its real on-screen home is the simplest visible anchor
        guard WindowMover.move(h.item.windowNumber, to: anchor.origin) else {
            Log.line("restore-to-anchor failed"); return
        }
        // CGEvent uses global coords with top-left origin — same space as CGWindow bounds.
        let click = CGPoint(x: anchor.midX, y: anchor.midY)
        synthesizeLeftClick(at: click)
        Log.line("clicked \(h.item.ownerName) at \(click); observe its menu, then it re-hides in 5s")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard let h = self.hidden else { return }
            let ok = WindowMover.move(h.item.windowNumber, to: WindowMover.offscreenPoint)
            Log.line("re-hide after dismiss window ok=\(ok)")
        }
    }

    private func synthesizeLeftClick(at p: CGPoint) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown,
                           mouseCursorPosition: p, mouseButton: .left)
        let up = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp,
                         mouseCursorPosition: p, mouseButton: .left)
        down?.post(tap: .cghidEventTap)
        usleep(60_000)
        up?.post(tap: .cghidEventTap)
    }
}
