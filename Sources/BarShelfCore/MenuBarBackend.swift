import Foundation

/// The version-fragility seam (spec §3). Plan 2B implements `TahoeBackend`
/// (Ice-style ⌘-drag + dividers/spacer + per-display + immovable detection).
/// Core/tests use `MockBackend` only.
public protocol MenuBarBackend: AnyObject {
    func enumerateStatusItems() -> [ItemSnapshot]            // per display
    func move(_ id: StableItemID, to: Placement)             // ⌘-drag in 2B
    func setShelfHidden(_ hidden: Bool)                      // spacer length in 2B
    func captureIcon(for id: StableItemID) -> Data?          // on-demand bitmap
    func observeChanges(_ onChange: @escaping () -> Void)
}

public final class MockBackend: MenuBarBackend {
    public init() {}
    public var live: [ItemSnapshot] = []
    public private(set) var moves: [(StableItemID, Placement)] = []
    public private(set) var shelfHidden = false
    private var onChange: (() -> Void)?

    public func enumerateStatusItems() -> [ItemSnapshot] { live }
    public func move(_ id: StableItemID, to p: Placement) { moves.append((id, p)) }
    public func setShelfHidden(_ h: Bool) { shelfHidden = h }
    public func captureIcon(for id: StableItemID) -> Data? { nil }
    public func observeChanges(_ cb: @escaping () -> Void) { onChange = cb }
    public func fireChange() { onChange?() }
}
