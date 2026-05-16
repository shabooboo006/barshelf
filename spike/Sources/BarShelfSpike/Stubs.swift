import Foundation

// Temporary stubs so Task 0 builds standalone. Replaced by real implementations
// in Plan-Tasks 1, 2, 4. Do not expand these.
@MainActor
final class MenuBarScan {
    static let shared = MenuBarScan()
    func logAll() { Log.line("MenuBarScan stub") }
}
@MainActor
final class RoundTrip {
    static let shared = RoundTrip()
    func hideFirstForeignItem() { Log.line("RoundTrip stub: hide") }
    func restoreHidden() { Log.line("RoundTrip stub: restore") }
    func fullRoundTrip() { Log.line("RoundTrip stub: roundtrip") }
}
