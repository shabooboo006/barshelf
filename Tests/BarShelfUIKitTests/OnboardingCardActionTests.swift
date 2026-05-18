import XCTest
@testable import BarShelfUIKit

/// Records which permissions were requested (stands in for the live
/// CGRequestScreenCaptureAccess / AXIsProcessTrustedWithOptions calls).
private final class SpyRequester: PermissionRequester, @unchecked Sendable {
    private(set) var requested: [PermissionKind] = []
    func request(_ kind: PermissionKind) { requested.append(kind) }
}

/// The rc1 deadlock: the onboarding "打开系统设置" action only opened the Settings
/// URL and never *requested* the OS permission, so macOS never registered BarShelf
/// in the Screen Recording TCC pane → no toggle row → ungrantable. These lock in
/// that the action requests the permission (registering the app) before deep-linking.
final class OnboardingCardActionTests: XCTestCase {
    func testScreenRecordingActionRequestsScreenRecording() {
        let spy = SpyRequester()
        let action = OnboardingCardAction(
            kind: .screenRecording,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        )
        action.perform(requester: spy, openURL: { _ in })
        XCTAssertEqual(spy.requested, [.screenRecording],
                       "must request Screen Recording so macOS registers BarShelf in the TCC pane")
    }

    func testAccessibilityActionRequestsAccessibility() {
        let spy = SpyRequester()
        let action = OnboardingCardAction(
            kind: .accessibility,
            settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        action.perform(requester: spy, openURL: { _ in })
        XCTAssertEqual(spy.requested, [.accessibility])
    }

    func testActionOpensTheSettingsURL() {
        var opened: [String] = []
        let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        let action = OnboardingCardAction(kind: .screenRecording, settingsURL: url)
        action.perform(requester: SpyRequester(), openURL: { opened.append($0) })
        XCTAssertEqual(opened, [url])
    }

    func testPermissionIsRequestedBeforeSettingsOpens() {
        // The TCC row must exist before the user lands in the pane, so the
        // request must fire before the deep-link.
        final class OrderRequester: PermissionRequester, @unchecked Sendable {
            let sink: (String) -> Void
            init(_ s: @escaping (String) -> Void) { sink = s }
            func request(_ kind: PermissionKind) { sink("request") }
        }
        var events: [String] = []
        let action = OnboardingCardAction(kind: .screenRecording, settingsURL: "u")
        action.perform(requester: OrderRequester { events.append($0) },
                       openURL: { _ in events.append("open") })
        XCTAssertEqual(events, ["request", "open"])
    }
}
