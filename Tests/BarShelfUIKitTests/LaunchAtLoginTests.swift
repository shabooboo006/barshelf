import XCTest
@testable import BarShelfUIKit

final class LaunchAtLoginTests: XCTestCase {
    final class FakeService: LoginItemService {
        var registered = false
        var registerError: Error?
        var unregisterError: Error?
        func register() throws { if let e = registerError { throw e } ; registered = true }
        func unregister() throws { if let e = unregisterError { throw e } ; registered = false }
    }
    struct Boom: Error {}

    func testEnableRegisters() {
        let s = FakeService(); let c = LaunchAtLoginController(service: s)
        c.setEnabled(true)
        XCTAssertTrue(s.registered); XCTAssertTrue(c.isEnabled)
    }
    func testDisableUnregisters() {
        let s = FakeService(); s.registered = true
        let c = LaunchAtLoginController(service: s)
        XCTAssertTrue(c.isEnabled)
        c.setEnabled(false)
        XCTAssertFalse(s.registered); XCTAssertFalse(c.isEnabled)
    }
    func testRegisterErrorSwallowed_stateReflectsService() {
        let s = FakeService(); s.registerError = Boom()
        let c = LaunchAtLoginController(service: s)
        c.setEnabled(true)   // must not crash
        XCTAssertFalse(s.registered); XCTAssertFalse(c.isEnabled)
    }
}
