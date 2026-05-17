import XCTest
@testable import BarShelfCore

final class MockBackendTests: XCTestCase {
    func testMockRecordsMoves() {
        let b = MockBackend()
        b.live = [ItemSnapshot(id: .init(bundleID: "a", titleKey: ""), displayID: 1, isImmovable: false)]
        XCTAssertEqual(b.enumerateStatusItems().count, 1)
        b.move(.init(bundleID: "a", titleKey: ""), to: .shelf)
        XCTAssertEqual(b.moves.last?.1, .shelf)
    }
}
