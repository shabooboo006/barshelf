/// Pure state machine (spec §5). No system APIs. Fully unit-tested.
public enum ShelfController {
    /// - Parameter knownShelved: ids the backend currently has parked off-screen
    ///   (⌘-drag hide mechanic). These are absent from `live` (off the visible
    ///   bar) yet must still receive a placement so they can be restored — else
    ///   a hidden item could never come back. `live` wins on overlap.
    public static func desiredVisibility(
        states: [StableItemID: ItemState],
        live: [ItemSnapshot],
        knownShelved: Set<StableItemID> = [],
        frontmost: String,
        expanded: Bool
    ) -> [StableItemID: Placement] {
        var out: [StableItemID: Placement] = [:]

        for item in live {
            if item.isImmovable { out[item.id] = .visible; continue }   // forced
            out[item.id] = placement(for: states[item.id] ?? .alwaysVisible,
                                     bundleID: item.id.bundleID,
                                     frontmost: frontmost, expanded: expanded)
        }

        // Parked items are off the visible bar so they never appear in `live`;
        // still emit a placement so expand / show-when-active can restore them.
        for id in knownShelved where out[id] == nil {
            out[id] = placement(for: states[id] ?? .alwaysVisible,
                                bundleID: id.bundleID,
                                frontmost: frontmost, expanded: expanded)
        }
        return out
    }

    private static func placement(
        for state: ItemState, bundleID: String, frontmost: String, expanded: Bool
    ) -> Placement {
        switch state {
        case .alwaysVisible:
            return .visible
        case .shelved:
            return expanded ? .visible : .shelf
        case .showWhenActive:
            return (frontmost == bundleID || expanded) ? .visible : .shelf
        }
    }

    /// Minimal diff: only items whose placement differs from `from`.
    public static func changes(
        from: [StableItemID: Placement], to: [StableItemID: Placement]
    ) -> [StableItemID: Placement] {
        var d: [StableItemID: Placement] = [:]
        for (id, p) in to where from[id] != p { d[id] = p }
        return d
    }
}
