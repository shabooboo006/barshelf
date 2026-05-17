import XCTest
@testable import BarShelfUIKit

final class PermissionsDecisionTests: XCTestCase {
    func testReadyWhenBoth() {
        XCTAssertEqual(PermissionsDecision.decide(ax: true, screen: true), .ready)
        XCTAssertTrue(PermissionsDecision.decide(ax: true, screen: true).isReady)
    }
    func testNeedsAccessibility() {
        XCTAssertEqual(PermissionsDecision.decide(ax: false, screen: true), .needsAccessibility)
        XCTAssertFalse(PermissionsDecision.decide(ax: false, screen: true).isReady)
    }
    func testNeedsScreenRecording() {
        XCTAssertEqual(PermissionsDecision.decide(ax: true, screen: false), .needsScreenRecording)
    }
    func testNeedsBoth() {
        XCTAssertEqual(PermissionsDecision.decide(ax: false, screen: false), .needsBoth)
    }
}
