import Foundation

public protocol KeyValueStore: AnyObject {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
}

public final class ClassificationStore {
    private static let key = "BarShelf.classification.v1"
    private struct Pair: Codable { let id: StableItemID; let state: ItemState }
    private let kv: KeyValueStore
    private var map: [StableItemID: ItemState]

    public init(kv: KeyValueStore) {
        self.kv = kv
        if let d = kv.data(forKey: Self.key),
           let arr = try? JSONDecoder().decode([Pair].self, from: d) {
            map = Dictionary(uniqueKeysWithValues: arr.map { ($0.id, $0.state) })
        } else {
            map = [:]   // migration tolerance: unknown/corrupt → empty (safe default upstream)
        }
    }

    public func state(for id: StableItemID) -> ItemState? { map[id] }

    public func set(_ s: ItemState, for id: StableItemID) {
        map[id] = s
        let arr = map.map { Pair(id: $0.key, state: $0.value) }
        kv.set(try? JSONEncoder().encode(arr), forKey: Self.key)
    }

    public func all() -> [StableItemID: ItemState] { map }
}
