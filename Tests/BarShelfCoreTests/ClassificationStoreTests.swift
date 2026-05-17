import XCTest
@testable import BarShelfCore

final class ClassificationStoreTests: XCTestCase {
    /// In-memory KV double (UserDefaults injected in the real app).
    final class MemKV: KeyValueStore {
        var data: Data?
        func data(forKey k: String) -> Data? { data }
        func set(_ d: Data?, forKey k: String) { data = d }
    }

    func testRoundTrip() {
        let kv = MemKV()
        let s = ClassificationStore(kv: kv)
        let id = StableItemID(bundleID: "a", titleKey: "t")
        s.set(.shelved, for: id)
        XCTAssertEqual(ClassificationStore(kv: kv).state(for: id), .shelved)
    }

    func testUnknownIdReturnsNil_callerAppliesSafeDefault() {
        XCTAssertNil(ClassificationStore(kv: MemKV()).state(for:
            StableItemID(bundleID: "x", titleKey: "")))
    }

    func testCorruptBlobToleratedAsEmpty() {
        let kv = MemKV(); kv.data = Data("not json".utf8)
        let s = ClassificationStore(kv: kv)
        XCTAssertNil(s.state(for: StableItemID(bundleID: "a", titleKey: "")))
        s.set(.alwaysVisible, for: StableItemID(bundleID: "a", titleKey: ""))   // still writable
        XCTAssertEqual(s.state(for: StableItemID(bundleID: "a", titleKey: "")), .alwaysVisible)
    }
}
