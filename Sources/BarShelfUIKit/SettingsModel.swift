import Foundation
import BarShelfCore

/// Testable bridge between the capability layer and the SwiftUI settings view.
/// No SwiftUI or AppKit import — pure logic, fully unit-testable.
///
/// `@MainActor` because `rows` is mutated and read on the main actor (bound to
/// a SwiftUI view).  The thumbnail closure is injected so tests can supply `nil`
/// without pulling in ScreenCaptureKit.
@MainActor
public final class SettingsModel {

    // MARK: – Row

    public struct Row: Equatable {
        public let id: StableItemID
        public let appName: String
        public let state: ItemState
        public let immovable: Bool
    }

    // MARK: – Public state

    public private(set) var rows: [Row] = []

    // MARK: – Dependencies

    private let backend: MenuBarBackend
    private let store: ClassificationStore
    private let registry: StatusItemRegistry
    private let thumbnail: @Sendable (StableItemID) async -> Data?

    // MARK: – Init

    public init(
        backend: MenuBarBackend,
        store: ClassificationStore,
        registry: StatusItemRegistry,
        thumbnail: @escaping @Sendable (StableItemID) async -> Data?
    ) {
        self.backend   = backend
        self.store     = store
        self.registry  = registry
        self.thumbnail = thumbnail
    }

    // MARK: – Reload

    /// Re-enumerates live items, reconciles with stored states, and rebuilds `rows`.
    /// Immovable items are always forced to `.alwaysVisible`; their state cannot be
    /// changed by the user (safe-default rule: never hide what we can't re-identify).
    public func reload() {
        let live      = backend.enumerateStatusItems()
        let effective = registry.reconcile(live: live, stored: store.all())

        // Build a lookup: id → isImmovable
        var immovableByID: [StableItemID: Bool] = [:]
        for snapshot in live {
            immovableByID[snapshot.id] = snapshot.isImmovable
        }

        rows = live
            .map { snapshot -> Row in
                let id        = snapshot.id
                let isImm     = snapshot.isImmovable
                let state: ItemState = isImm ? .alwaysVisible : (effective[id] ?? .alwaysVisible)
                return Row(
                    id:        id,
                    appName:   id.bundleID,
                    state:     state,
                    immovable: isImm
                )
            }
            .sorted { $0.appName < $1.appName }
    }

    // MARK: – setState

    /// Sets a new state for the given item.  No-op if the item is immovable.
    /// After persisting, calls `reload()` to refresh `rows`.
    public func setState(_ s: ItemState, for id: StableItemID) {
        // Guard: no-op for immovable items
        guard let row = rows.first(where: { $0.id == id }), !row.immovable else { return }
        store.set(s, for: id)
        reload()
    }

    // MARK: – Thumbnail accessor (for SwiftUI layer)

    /// Convenience so the SwiftUI view can call the injected closure.
    public func thumbnailData(for id: StableItemID) async -> Data? {
        await thumbnail(id)
    }
}
