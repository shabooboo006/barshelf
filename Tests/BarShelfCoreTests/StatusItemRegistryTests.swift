import XCTest
@testable import BarShelfCore

final class StatusItemRegistryTests: XCTestCase {
    private func snap(_ b: String, _ t: String = "") -> ItemSnapshot {
        ItemSnapshot(id: StableItemID(bundleID: b, titleKey: t), displayID: 1, isImmovable: false)
    }

    func testNewItemGetsSafeDefaultAlwaysVisible() {
        let r = StatusItemRegistry()
        let eff = r.reconcile(live: [snap("a")], stored: [:])
        XCTAssertEqual(eff[StableItemID(bundleID: "a", titleKey: "")], .alwaysVisible)
    }

    func testStoredStateAppliedWhenMatched() {
        let r = StatusItemRegistry()
        let id = StableItemID(bundleID: "a", titleKey: "")
        XCTAssertEqual(r.reconcile(live: [snap("a")], stored: [id: .shelved])[id], .shelved)
    }

    func testStoredButCurrentlyAbsentItemRetained() {
        let r = StatusItemRegistry()
        let gone = StableItemID(bundleID: "z", titleKey: "")
        _ = r.reconcile(live: [snap("a")], stored: [gone: .shelved])
        XCTAssertTrue(r.retainedAbsent.contains(gone))
    }

    func testAmbiguousIdentity_safeDefaultVisible_notHidden() {
        let r = StatusItemRegistry()
        let id = StableItemID(bundleID: "dup", titleKey: "")
        let eff = r.reconcile(live: [snap("dup"), snap("dup")], stored: [id: .shelved])
        XCTAssertEqual(eff[id], .alwaysVisible, "ambiguous identity must not be hidden")
    }
}
