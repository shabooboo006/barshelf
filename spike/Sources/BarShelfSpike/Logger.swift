import AppKit

/// Visible on-screen console. The spike's whole purpose is human verification,
/// so every action MUST show its result somewhere the operator can see — not
/// only stderr (invisible when the .app is launched from Finder).
@MainActor
final class LogConsole {
    static let shared = LogConsole()

    private var panel: NSPanel?
    private var textView: NSTextView?
    private let mono = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
    private lazy var stamp: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f
    }()

    private func ensurePanel() {
        guard panel == nil else { return }
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 440),
            styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
            backing: .buffered, defer: false)
        p.title = "BarShelf Spike 日志"
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        let scroll = NSScrollView(frame: p.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        let tv = NSTextView(frame: scroll.bounds)
        tv.isEditable = false
        tv.isRichText = false
        tv.font = mono
        tv.textContainerInset = NSSize(width: 8, height: 8)
        tv.autoresizingMask = [.width]
        scroll.documentView = tv
        p.contentView?.addSubview(scroll)
        p.center()
        panel = p
        textView = tv
        append("日志窗口已就绪。点击菜单栏 ▣ 执行各步骤，结果会显示在这里。")
    }

    func show() {
        ensurePanel()
        panel?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func append(_ msg: String) {
        ensurePanel()
        guard let tv = textView else { return }
        let line = "\(stamp.string(from: Date()))  \(msg)\n"
        tv.textStorage?.append(NSAttributedString(
            string: line,
            attributes: [.font: mono, .foregroundColor: NSColor.textColor]))
        tv.scrollToEndOfDocument(nil)
        panel?.orderFrontRegardless()
    }
}

enum Log {
    /// Mirrors to stderr (useful from a terminal) AND to the visible console.
    static func line(_ s: String) {
        FileHandle.standardError.write(Data("[spike] \(s)\n".utf8))
        let captured = s
        Task { @MainActor in LogConsole.shared.append(captured) }
    }
}
