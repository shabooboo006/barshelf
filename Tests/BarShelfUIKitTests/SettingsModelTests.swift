import XCTest
@testable import BarShelfUIKit
import BarShelfCore
import BarShelfCoreTestSupport

// In-memory KeyValueStore for tests (same pattern as prior tests).
private final class InMemoryKV: KeyValueStore {
    private var store: [String: Data] = [:]
    func data(forKey key: String) -> Data? { store[key] }
    func set(_ data: Data?, forKey key: String) { store[key] = data }
}

@MainActor
final class SettingsModelTests: XCTestCase {

    // MARK: – Helpers

    private func makeIDs() -> (normal: StableItemID, immovable: StableItemID) {
        let normal    = StableItemID(bundleID: "com.a", titleKey: "A")
        let immovable = StableItemID(bundleID: "com.apple.controlcenter", titleKey: "CC")
        return (normal, immovable)
    }

    private func seedBackend(_ backend: MockBackend) -> (normal: StableItemID, immovable: StableItemID) {
        let ids = makeIDs()
        backend.live = [
            ItemSnapshot(id: ids.normal,    displayID: 1, isImmovable: false),
            ItemSnapshot(id: ids.immovable, displayID: 1, isImmovable: true),
        ]
        return ids
    }

    // MARK: – Tests

    /// After reload, normal item's state comes from the store; immovable item is
    /// forced to .alwaysVisible regardless of what is stored.
    func testReload_rowsReflectStoredStatesAndImmovableForced() throws {
        let backend  = MockBackend()
        let kv       = InMemoryKV()
        let store    = ClassificationStore(kv: kv)
        let registry = StatusItemRegistry()
        let ids      = seedBackend(backend)

        // Seed the store: mark normal item as .shelved
        store.set(.shelved, for: ids.normal)

        let model = SettingsModel(
            backend:   backend,
            store:     store,
            registry:  registry,
            thumbnail: { _ in nil }
        )
        model.reload()

        XCTAssertEqual(model.rows.count, 2)

        let normalRow = try XCTUnwrap(model.rows.first { $0.id == ids.normal })
        XCTAssertEqual(normalRow.state,     .shelved)
        XCTAssertFalse(normalRow.immovable)

        let ccRow = try XCTUnwrap(model.rows.first { $0.id == ids.immovable })
        XCTAssertEqual(ccRow.state,    .alwaysVisible)
        XCTAssertTrue(ccRow.immovable)
    }

    /// setState persists through the store so a new SettingsModel over the same
    /// KV store sees the updated state.
    func testSetState_persistsThroughStore() throws {
        let backend  = MockBackend()
        let kv       = InMemoryKV()
        let store    = ClassificationStore(kv: kv)
        let registry = StatusItemRegistry()
        let ids      = seedBackend(backend)

        let model = SettingsModel(
            backend:   backend,
            store:     store,
            registry:  registry,
            thumbnail: { _ in nil }
        )
        model.reload()

        model.setState(.shelved, for: ids.normal)

        // Read back through a fresh model over the same KV store
        let store2    = ClassificationStore(kv: kv)
        let registry2 = StatusItemRegistry()
        let model2    = SettingsModel(
            backend:   backend,
            store:     store2,
            registry:  registry2,
            thumbnail: { _ in nil }
        )
        model2.reload()

        let row2 = try XCTUnwrap(model2.rows.first { $0.id == ids.normal })
        XCTAssertEqual(row2.state, .shelved)
    }

    /// setState on an immovable item is a no-op: the row stays .alwaysVisible
    /// and nothing is written to the store.
    func testSetState_immovableIsNoOp() throws {
        let backend  = MockBackend()
        let kv       = InMemoryKV()
        let store    = ClassificationStore(kv: kv)
        let registry = StatusItemRegistry()
        let ids      = seedBackend(backend)

        let model = SettingsModel(
            backend:   backend,
            store:     store,
            registry:  registry,
            thumbnail: { _ in nil }
        )
        model.reload()

        // Attempt to shelve the immovable item
        model.setState(.shelved, for: ids.immovable)

        let ccRow = try XCTUnwrap(model.rows.first { $0.id == ids.immovable })
        XCTAssertEqual(ccRow.state, .alwaysVisible, "immovable row must stay .alwaysVisible")

        // Store should still have no entry for the immovable id
        XCTAssertNil(store.state(for: ids.immovable), "store must not persist state for immovable item")
    }

    /// Rows are sorted by appName (== bundleID) ascending.
    func testReload_rowsSortedByAppName() {
        let backend  = MockBackend()
        let kv       = InMemoryKV()
        let store    = ClassificationStore(kv: kv)
        let registry = StatusItemRegistry()

        // "com.apple.controlcenter" < "com.a" lexicographically? No — let's verify
        // the actual sort by checking the order in model.rows.
        backend.live = [
            ItemSnapshot(id: StableItemID(bundleID: "com.z", titleKey: ""), displayID: 1, isImmovable: false),
            ItemSnapshot(id: StableItemID(bundleID: "com.a", titleKey: ""), displayID: 1, isImmovable: false),
        ]

        let model = SettingsModel(
            backend:   backend,
            store:     store,
            registry:  registry,
            thumbnail: { _ in nil }
        )
        model.reload()

        XCTAssertEqual(model.rows.count, 2)
        XCTAssertEqual(model.rows[0].appName, "com.a")
        XCTAssertEqual(model.rows[1].appName, "com.z")
    }

    /// Row.appName equals the bundleID.
    func testReload_rowAppNameEqualsBundleID() throws {
        let backend  = MockBackend()
        let kv       = InMemoryKV()
        let store    = ClassificationStore(kv: kv)
        let registry = StatusItemRegistry()
        let ids      = seedBackend(backend)

        let model = SettingsModel(
            backend:   backend,
            store:     store,
            registry:  registry,
            thumbnail: { _ in nil }
        )
        model.reload()

        let row = try XCTUnwrap(model.rows.first { $0.id == ids.normal })
        XCTAssertEqual(row.appName, ids.normal.bundleID)
    }
}
