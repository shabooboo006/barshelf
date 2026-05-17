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
