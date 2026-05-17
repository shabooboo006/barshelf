/// Reconciles live snapshots to stored identities (spec §6). Any uncertainty
/// (new item, ambiguous duplicate identity) → safe default 常显 (.alwaysVisible).
public final class StatusItemRegistry {
    public private(set) var retainedAbsent: Set<StableItemID> = []
    public init() {}

    public func reconcile(
        live: [ItemSnapshot],
        stored: [StableItemID: ItemState]
    ) -> [StableItemID: ItemState] {
        var counts: [StableItemID: Int] = [:]
        for s in live { counts[s.id, default: 0] += 1 }

        var effective: [StableItemID: ItemState] = [:]
        for s in live {
            if counts[s.id]! > 1 {                 // ambiguous → never hide
                effective[s.id] = .alwaysVisible
            } else {
                effective[s.id] = stored[s.id] ?? .alwaysVisible   // safe default
            }
        }
        let liveIDs = Set(live.map(\.id))
        retainedAbsent = Set(stored.keys).subtracting(liveIDs)      // keep for return
        return effective
    }
}
