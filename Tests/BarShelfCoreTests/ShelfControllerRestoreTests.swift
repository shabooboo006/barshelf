import XCTest
@testable import BarShelfCore

/// With the ⌘-drag-off-screen hide mechanic, a shelved item is no longer
/// enumerated (it's off the visible bar), so it drops out of `live`. The
/// controller must still emit a placement for such "known shelved" items, or
/// they could never be restored — CLAUDE.md: never hide what the user can't
/// get back.
final class ShelfControllerRestoreTests: XCTestCase {
    private func id(_ b: String) -> StableItemID { StableItemID(bundleID: b, titleKey: "") }

    func testKnownShelvedAbsentFromLive_restoredOnExpand() {
        let i = id("a")
        let out = ShelfController.desiredVisibility(
            states: [i: .shelved], live: [], knownShelved: [i],
            frontmost: "x", expanded: true)
        XCTAssertEqual(out[i], .visible, "expanding must restore an off-screen shelved item")
    }

    func testKnownShelvedAbsentFromLive_staysHiddenWhenCollapsed() {
        let i = id("a")
        let out = ShelfController.desiredVisibility(
            states: [i: .shelved], live: [], knownShelved: [i],
            frontmost: "x", expanded: false)
        XCTAssertEqual(out[i], .shelf, "still collapsed → stay hidden")
    }

    func testKnownShelvedShowWhenActive_restoredWhenOwnerFrontmost() {
        let i = id("com.acme.app")
        let out = ShelfController.desiredVisibility(
            states: [i: .showWhenActive], live: [], knownShelved: [i],
            frontmost: "com.acme.app", expanded: false)
        XCTAssertEqual(out[i], .visible)
    }

    func testKnownShelvedButNotActuallyShelvedState_safeDefaultRestore() {
        // If an item we parked is somehow classified alwaysVisible, restore it
        // (safe default: don't strand a visible item off-screen).
        let i = id("a")
        let out = ShelfController.desiredVisibility(
            states: [i: .alwaysVisible], live: [], knownShelved: [i],
            frontmost: "x", expanded: false)
        XCTAssertEqual(out[i], .visible)
    }

    func testLiveItemNotDuplicatedByKnownShelved() {
        let i = id("a")
        let live = [ItemSnapshot(id: i, displayID: 1, isImmovable: false)]
        let out = ShelfController.desiredVisibility(
            states: [i: .shelved], live: live, knownShelved: [i],
            frontmost: "x", expanded: false)
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(out[i], .shelf)
    }
}
