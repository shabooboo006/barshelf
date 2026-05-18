import XCTest
import CoreGraphics
@testable import BarShelfBackend

/// Pure off-screen / visible X math for the ⌘-drag hide mechanic that replaced
/// the unsound 10 000 pt spacer-collapse (rc2 Central-Risk regression).
final class MenuBarGeometryTests: XCTestCase {

    // Primary display at the global origin.
    private let primary = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    // A display arranged to the LEFT of the origin (negative minX).
    private let leftArranged = CGRect(x: -2560, y: 0, width: 2560, height: 1440)

    func testShelfXIsLeftOfDisplayByMoreThanAnyItemWidth() {
        let x = MenuBarGeometry.shelfX(displayBounds: primary)
        // Must be far enough left that a plausibly-wide (~200 pt) status item's
        // midX still falls left of the display → excluded from enumeration (hidden).
        XCTAssertLessThan(x + 200, primary.minX,
                          "a shelved item's midX must be left of the display so it is hidden")
    }

    func testShelfXAlsoHidesOnLeftArrangedDisplay() {
        let x = MenuBarGeometry.shelfX(displayBounds: leftArranged)
        XCTAssertLessThan(x + 200, leftArranged.minX)
    }

    func testVisibleXKeepsAValidLastKnownPosition() {
        let x = MenuBarGeometry.visibleX(displayBounds: primary, lastItemMinX: 1500)
        XCTAssertEqual(x, 1500, "an in-range last position should be reused for restore")
    }

    func testVisibleXFallsBackInsideTheBarWhenLastUnknown() {
        let x = MenuBarGeometry.visibleX(displayBounds: primary, lastItemMinX: nil)
        XCTAssertGreaterThanOrEqual(x, primary.minX)
        XCTAssertLessThan(x, primary.maxX)
    }

    func testVisibleXFallsBackWhenLastPositionIsOffDisplay() {
        // A stale off-screen (shelved) minX must NOT be reused as a "visible" anchor.
        let stale = MenuBarGeometry.shelfX(displayBounds: primary)
        let x = MenuBarGeometry.visibleX(displayBounds: primary, lastItemMinX: stale)
        XCTAssertGreaterThanOrEqual(x, primary.minX)
        XCTAssertLessThan(x, primary.maxX)
    }
}
