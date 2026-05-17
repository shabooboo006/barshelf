import AppKit
import CoreGraphics

@MainActor
final class RoundTrip {
    static let shared = RoundTrip()

    private var hidden: (item: ForeignStatusItem, originalCGBounds: CGRect)?

    func hideFirstForeignItem() {
        let items = MenuBarScan.shared.scan()
        guard let target = items.first else { Log.line("没有外部图标（先确认 ② 扫描有结果）"); return }
        guard let original = WindowMover.bounds(target.windowNumber) else {
            Log.line("无法读取窗口边界；中止"); return
        }
        let ok = WindowMover.move(target.windowNumber, to: WindowMover.offscreenPoint)
        Log.line("隐藏 \(target.ownerName) 窗口=\(target.windowNumber) 成功=\(ok) —— 观察该图标是否从菜单栏消失")
        if ok { hidden = (target, original) }
    }

    func restoreHidden() {
        guard let h = hidden else { Log.line("当前没有已隐藏的图标"); return }
        let ok = WindowMover.move(h.item.windowNumber, to: h.originalCGBounds.origin)
        Log.line("恢复 \(h.item.ownerName) 成功=\(ok) —— 观察该图标是否回到菜单栏")
        if ok { hidden = nil }
    }

    /// Restore the hidden item to a VISIBLE anchor, synthesize a visible click,
    /// wait, then move it back off-screen.
    func fullRoundTrip() {
        guard let h = hidden else { Log.line("没有已隐藏的图标；请先执行 ③ 隐藏"); return }
        let anchor = h.originalCGBounds // its real on-screen home is the simplest visible anchor
        guard WindowMover.move(h.item.windowNumber, to: anchor.origin) else {
            Log.line("恢复到锚点失败"); return
        }
        // CGEvent uses global coords with top-left origin — same space as CGWindow bounds.
        let click = CGPoint(x: anchor.midX, y: anchor.midY)
        synthesizeLeftClick(at: click)
        Log.line("已点击 \(h.item.ownerName) 于 \(click)；请观察其菜单是否在屏幕上正常弹出，5 秒后将自动重新隐藏")

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard let h = self.hidden else { return }
            let ok = WindowMover.move(h.item.windowNumber, to: WindowMover.offscreenPoint)
            Log.line("关闭窗口后重新隐藏 成功=\(ok)")
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
