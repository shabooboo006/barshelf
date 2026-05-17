import XCTest
@testable import BarShelfCore

final class ShelfControllerTests: XCTestCase {
    private func snap(_ b: String, _ disp: UInt32 = 1, immovable: Bool = false) -> ItemSnapshot {
        ItemSnapshot(id: StableItemID(bundleID: b, titleKey: ""), displayID: disp, isImmovable: immovable)
    }

    func testAlwaysVisible_isAlwaysVisible() {
        let s = snap("a")
        let out = ShelfController.desiredVisibility(
            states: [s.id: .alwaysVisible], live: [s], frontmost: "x", expanded: false)
        XCTAssertEqual(out[s.id], .visible)
    }

    func testShelved_collapsedHidden_expandedVisible() {
        let s = snap("a")
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .shelved], live: [s], frontmost: "x", expanded: false)[s.id], .shelf)
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .shelved], live: [s], frontmost: "x", expanded: true)[s.id], .visible)
    }

    func testShowWhenActive_visibleOnlyWhenOwnerFrontmostOrExpanded() {
        let s = snap("com.acme.app")
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .showWhenActive], live: [s], frontmost: "com.acme.app", expanded: false)[s.id], .visible)
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .showWhenActive], live: [s], frontmost: "other", expanded: false)[s.id], .shelf)
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .showWhenActive], live: [s], frontmost: "other", expanded: true)[s.id], .visible)
    }

    func testImmovable_forcedVisible_evenIfShelved() {
        let s = snap("com.apple.controlcenter", immovable: true)
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [s.id: .shelved], live: [s], frontmost: "x", expanded: false)[s.id], .visible)
    }

    func testUnknownItem_safeDefaultVisible() {
        let s = snap("new")
        XCTAssertEqual(ShelfController.desiredVisibility(
            states: [:], live: [s], frontmost: "x", expanded: false)[s.id], .visible)
    }

    func testOnlyChangedItemsReported_diff() {
        let a = snap("a"), b = snap("b")
        let prev: [StableItemID: Placement] = [a.id: .visible, b.id: .visible]
        let next = ShelfController.desiredVisibility(
            states: [b.id: .shelved], live: [a, b], frontmost: "x", expanded: false)
        XCTAssertEqual(ShelfController.changes(from: prev, to: next), [b.id: .shelf])
    }
}
