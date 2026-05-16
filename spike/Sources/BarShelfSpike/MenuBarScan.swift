import AppKit
@preconcurrency import CoreGraphics

struct ForeignStatusItem {
    let windowNumber: UInt32
    let ownerPID: pid_t
    let ownerName: String
    let bounds: CGRect   // CG global coords (top-left origin)
}

@MainActor
final class MenuBarScan {
    static let shared = MenuBarScan()

    func scan() -> [ForeignStatusItem] {
        let statusLayer = Int(CGWindowLevelForKey(.statusWindow)) // typically 25
        let mePID = getpid()
        guard let info = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return [] }

        var items: [ForeignStatusItem] = []
        for w in info {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == statusLayer,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t, pid != mePID,
                  let num = w[kCGWindowNumber as String] as? UInt32,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = b["X"], let y = b["Y"], let width = b["Width"], let height = b["Height"]
            else { continue }
            let name = (w[kCGWindowOwnerName as String] as? String) ?? "pid \(pid)"
            items.append(ForeignStatusItem(
                windowNumber: num, ownerPID: pid, ownerName: name,
                bounds: CGRect(x: x, y: y, width: width, height: height)))
        }
        return items.sorted { $0.bounds.minX < $1.bounds.minX }
    }

    func logAll() {
        let items = scan()
        Log.line("found \(items.count) foreign status items:")
        for it in items {
            Log.line("  win=\(it.windowNumber) pid=\(it.ownerPID) \(it.ownerName) bounds=\(it.bounds)")
        }
    }
}
