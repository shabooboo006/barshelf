// UserDefaultsKV.swift — BarShelf
//
// Bridges UserDefaults to the BarShelfCore `KeyValueStore` protocol.
//
// `UserDefaults.set(_:forKey:)` takes `Any?`, while `KeyValueStore.set(_:forKey:)`
// requires `Data?`. The signatures are not directly conformance-compatible in Swift 6,
// so we use a thin wrapper instead of a retroactive extension.

import Foundation
import BarShelfCore

final class UserDefaultsKV: KeyValueStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    func set(_ data: Data?, forKey key: String) {
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
