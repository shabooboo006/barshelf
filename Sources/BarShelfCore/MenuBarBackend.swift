import Foundation

/// The version-fragility seam (spec §3). `TahoeBackend` hides 收进架 items by
/// ⌘-dragging each off-screen (the on-device-verified `CmdDragMover` primitive)
/// and restoring them the same way — there is no spacer-collapse (the 10 000 pt
/// spacer pushed BarShelf's own icon off-screen on real hardware: rc2 Central
/// Risk #4). Core/tests use `MockBackend` only.
public protocol MenuBarBackend: AnyObject {
    func enumerateStatusItems() -> [ItemSnapshot]            // per display
    func move(_ id: StableItemID, to: Placement)             // ⌘-drag (on/off screen)
    func captureIcon(for id: StableItemID) -> Data?          // on-demand bitmap
    func observeChanges(_ onChange: @escaping () -> Void)
}
