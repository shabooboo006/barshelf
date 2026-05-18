import Foundation
import BarShelfCore

public final class MockBackend: MenuBarBackend {
    public init() {}
    public var live: [ItemSnapshot] = []
    public private(set) var moves: [(StableItemID, Placement)] = []
    private var onChange: (() -> Void)?

    public func enumerateStatusItems() -> [ItemSnapshot] { live }
    public func move(_ id: StableItemID, to p: Placement) { moves.append((id, p)) }
    public func captureIcon(for id: StableItemID) -> Data? { nil }
    public func observeChanges(_ cb: @escaping () -> Void) { onChange = cb }
    public func fireChange() { onChange?() }
}
