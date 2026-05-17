import XCTest
@testable import BarShelfCore

final class PipelineTests: XCTestCase {
    final class MemKV: KeyValueStore {
        var d: Data?
        func data(forKey k: String) -> Data? { d }
        func set(_ x: Data?, forKey k: String) { d = x }
    }

    func testEndToEndPureFlow() {
        let kv = MemKV()
        let store = ClassificationStore(kv: kv)
        let shelved = StableItemID(bundleID: "b", titleKey: "")
        store.set(.shelved, for: shelved)

        let backend = MockBackend()
        backend.live = [
            ItemSnapshot(id: .init(bundleID: "a", titleKey: ""), displayID: 1, isImmovable: false),
            ItemSnapshot(id: shelved, displayID: 1, isImmovable: false),
        ]
        let reg = StatusItemRegistry()
        let states = reg.reconcile(live: backend.enumerateStatusItems(), stored: store.all())

        let placement = ShelfController.desiredVisibility(
            states: states, live: backend.enumerateStatusItems(),
            frontmost: "none", expanded: false)

        for (id, p) in placement { backend.move(id, to: p) }
        XCTAssertTrue(backend.moves.contains { $0.0 == shelved && $0.1 == .shelf })
        XCTAssertTrue(backend.moves.contains {
            $0.0 == StableItemID(bundleID: "a", titleKey: "") && $0.1 == .visible })
    }
}
