import XCTest
@testable import BarShelfBackend

final class DisplayScannerLogicTests: XCTestCase {

    // Shared display setup: two displays.
    // Display A (large): bounds (0,0,2560,1440) — area 3,686,400  ← TARGET
    // Display B (small): bounds (2560,0,1920,1080) — area 2,073,600
    let displayA = DisplayRect(id: 1, bounds: CGRect(x: 0,    y: 0, width: 2560, height: 1440))
    let displayB = DisplayRect(id: 2, bounds: CGRect(x: 2560, y: 0, width: 1920, height: 1080))
    let statusLayer = 25   // representative CGWindowLevelForKey(.statusWindow) value

    // MARK: - 1. Real item on the largest display → belongs, not immovable

    func testRealItemOnLargestDisplay() {
        // Item sitting at the top-left of display A's menu bar
        let win = RawWindow(
            x: 40, y: 0, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1001
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "Item inside display A's menu bar should belong")
        XCTAssertEqual(result.displayID, displayA.id, "Should be attributed to the largest display (A)")
        XCTAssertFalse(result.immovable, "Generic app item should not be immovable")
    }

    // MARK: - 2. y far below menu bar → does not belong

    func testWindowFarBelowMenuBar() {
        let win = RawWindow(
            x: 100, y: displayA.bounds.minY - 500, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1002
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Window far below menu bar should not belong")
        XCTAssertNil(result.displayID)
    }

    // MARK: - 3. Wrong layer → does not belong

    func testWrongLayer() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 33,
            layer: statusLayer + 1,   // different from statusLayer
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1003
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Wrong-layer window should not belong")
        XCTAssertNil(result.displayID)
    }

    // MARK: - 4. Control Center cluster → belongs and immovable

    func testControlCenterImmovable() {
        // Control Center sits at the right edge of display A, wide panel
        let win = RawWindow(
            x: 2560 - 200, y: 0, w: 200, h: 33,
            layer: statusLayer,
            ownerPID: 200,
            ownerName: "Control Center",
            wid: 1004
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "Control Center should belong")
        XCTAssertTrue(result.immovable, "Control Center wide panel should be immovable")
        XCTAssertEqual(result.displayID, displayA.id)
    }

    func testBentoBoxImmovable() {
        let win = RawWindow(
            x: 2560 - 150, y: 0, w: 150, h: 33,
            layer: statusLayer,
            ownerPID: 201,
            ownerName: "BentoBox",
            wid: 1005
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "BentoBox should belong")
        XCTAssertTrue(result.immovable, "BentoBox wide panel should be immovable")
    }

    func testControlCenterNarrowNotImmovable() {
        // Control Center but width < 120 → not immovable
        let win = RawWindow(
            x: 2560 - 100, y: 0, w: 100, h: 33,
            layer: statusLayer,
            ownerPID: 200,
            ownerName: "Control Center",
            wid: 1006
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "Control Center narrow should still belong")
        XCTAssertFalse(result.immovable, "Control Center width < 120 should NOT be immovable")
    }

    // MARK: - 5. Our own parked window (x <= -5000) → does not belong

    func testOwnParkedWindowExcluded() {
        let win = RawWindow(
            x: -5000, y: 0, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1007
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Parked window at x <= -5000 should be excluded")
        XCTAssertNil(result.displayID)
    }

    func testNegativeXBeyondThreshold() {
        // x = -5001 is also excluded
        let win = RawWindow(
            x: -5001, y: 0, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1008
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs)
    }

    // MARK: - 6. Item on the SMALLER display → does not belong (only largest = target)

    func testItemOnSmallerDisplayExcluded() {
        // Item at the top of display B (the smaller one)
        // midX = 2560 + 960 = 3520, which is inside display B but NOT display A
        let win = RawWindow(
            x: 2560 + 40, y: 0, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1009
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Item on smaller display B should not belong (only largest display is target)")
        XCTAssertNil(result.displayID)
    }

    // MARK: - 7. Edge cases: y at boundary

    func testWindowAtMinYMinus2Accepted() {
        // y == display.minY - 2 is accepted (spike guard: y >= db.minY - 2)
        let win = RawWindow(
            x: 100, y: displayA.bounds.minY - 2, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1010
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "y == minY-2 should be accepted (inclusive lower bound)")
    }

    func testWindowAtMinYPlus44Accepted() {
        // y == display.minY + 44 is accepted (inclusive upper bound)
        let win = RawWindow(
            x: 100, y: displayA.bounds.minY + 44, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1011
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "y == minY+44 should be accepted (inclusive upper bound)")
    }

    func testWindowAtMinYPlus45Rejected() {
        // y == display.minY + 45 exceeds the band → rejected
        let win = RawWindow(
            x: 100, y: displayA.bounds.minY + 45, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1012
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "y == minY+45 exceeds band, should be rejected")
    }

    // MARK: - 8. Height boundary checks

    func testHeightTooSmallRejected() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 17,   // h < 18
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1013
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Height < 18 should be rejected")
    }

    func testHeightTooLargeRejected() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 45,   // h > 44
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1014
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "Height > 44 should be rejected")
    }

    func testHeightMinBoundary() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 18,   // h == 18 → accepted
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1015
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "Height == 18 should be accepted")
    }

    func testHeightMaxBoundary() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 44,   // h == 44 → accepted
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1016
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertTrue(result.belongs, "Height == 44 should be accepted")
    }

    // MARK: - 9. midX boundary: item whose midX falls exactly on display A's maxX → rejected

    func testMidXAtMaxXBoundaryRejected() {
        // midX = displayA.maxX = 2560 → NOT in [minX, maxX)
        let win = RawWindow(
            x: 2560 - 1, y: 0, w: 2, h: 33,   // midX = 2560 exactly
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1017
        )
        let result = DisplayScanner.classify(win, displays: [displayA, displayB], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "midX == display.maxX should be rejected (half-open interval)")
    }

    // MARK: - 10. Empty displays list → no crash, belongs == false

    func testEmptyDisplaysNoCrash() {
        let win = RawWindow(
            x: 100, y: 0, w: 60, h: 33,
            layer: statusLayer,
            ownerPID: 1234,
            ownerName: "SomeApp",
            wid: 1018
        )
        let result = DisplayScanner.classify(win, displays: [], statusLayer: statusLayer)
        XCTAssertFalse(result.belongs, "No displays → should not belong, no crash")
        XCTAssertNil(result.displayID)
    }
}
