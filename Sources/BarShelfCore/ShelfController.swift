/// Pure state machine (spec §5). No system APIs. Fully unit-tested.
public enum ShelfController {
    public static func desiredVisibility(
        states: [StableItemID: ItemState],
        live: [ItemSnapshot],
        frontmost: String,
        expanded: Bool
    ) -> [StableItemID: Placement] {
        var out: [StableItemID: Placement] = [:]
        for item in live {
            if item.isImmovable { out[item.id] = .visible; continue }   // forced
            switch states[item.id] ?? .alwaysVisible {                   // safe default
            case .alwaysVisible:
                out[item.id] = .visible
            case .shelved:
                out[item.id] = expanded ? .visible : .shelf
            case .showWhenActive:
                out[item.id] = (frontmost == item.id.bundleID || expanded) ? .visible : .shelf
            }
        }
        return out
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
