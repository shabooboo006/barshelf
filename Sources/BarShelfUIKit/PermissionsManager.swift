public enum PermissionsDecision: Equatable, Sendable {
    case ready, needsAccessibility, needsScreenRecording, needsBoth
    public var isReady: Bool { self == .ready }
    public static func decide(ax: Bool, screen: Bool) -> PermissionsDecision {
        switch (ax, screen) {
        case (true, true):   return .ready
        case (false, true):  return .needsAccessibility
        case (true, false):  return .needsScreenRecording
        case (false, false): return .needsBoth
        }
    }
}

/// System probe seam (live impl lives in the BarShelf exe — NOT unit-tested here).
public protocol PermissionsProbe: Sendable {
    var axTrusted: Bool { get }
    var screenGranted: Bool { get }
}

public enum PermissionKind: Sendable, Equatable {
    case accessibility
    case screenRecording
}

/// Permission *request* seam (live impl lives in the BarShelf exe — NOT unit-tested
/// here; mirrors `PermissionsProbe`). Requesting — not merely preflighting — is what
/// makes macOS register BarShelf with TCC so a toggle row appears in the privacy
/// pane. `CGPreflightScreenCaptureAccess()` does NOT register the app; without an
/// actual request the Screen Recording row never appears and the permission is
/// ungrantable (the rc1 onboarding deadlock).
public protocol PermissionRequester: Sendable {
    func request(_ kind: PermissionKind)
}

/// An onboarding permission card's primary action. It MUST request the OS
/// permission (registering BarShelf with TCC + showing the system prompt) BEFORE
/// deep-linking to System Settings, so the toggle row exists when the user arrives.
public struct OnboardingCardAction: Sendable {
    public let kind: PermissionKind
    public let settingsURL: String

    public init(kind: PermissionKind, settingsURL: String) {
        self.kind = kind
        self.settingsURL = settingsURL
    }

    public func perform(requester: PermissionRequester, openURL: (String) -> Void) {
        requester.request(kind)   // registers the app with TCC + prompts — the fix
        openURL(settingsURL)      // then take the user to the (now-populated) pane
    }
}
