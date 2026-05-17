import Foundation

/// Stable cross-launch identity (spec §6): bundleID + AX title/identifier
/// heuristic. NEVER pid/coords/windowID (Control Center recycles wid).
public struct StableItemID: Hashable, Codable, Sendable {
    public let bundleID: String
    public let titleKey: String   // AX title/identifier heuristic; "" if unknown
    public init(bundleID: String, titleKey: String) {
        self.bundleID = bundleID; self.titleKey = titleKey
    }
}

public enum ItemState: String, Codable, Sendable, CaseIterable {
    case alwaysVisible   // 常显
    case shelved         // 收进架
    case showWhenActive  // 激活时显示
}

/// A live observed menu-bar item (one display). Mechanism-agnostic.
public struct ItemSnapshot: Hashable, Sendable {
    public let id: StableItemID
    public let displayID: UInt32
    public let isImmovable: Bool   // Control Center clock/Bento etc.
    public init(id: StableItemID, displayID: UInt32, isImmovable: Bool) {
        self.id = id; self.displayID = displayID; self.isImmovable = isImmovable
    }
}

public enum Placement: String, Sendable { case visible, shelf }
