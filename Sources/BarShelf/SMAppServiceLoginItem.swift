// SMAppServiceLoginItem.swift — BarShelf
//
// Production implementation of LoginItemService using SMAppService.
// Requires macOS 13+; trivially satisfied because V0 targets macOS 26.0.

import ServiceManagement
import BarShelfUIKit

// MARK: - SMAppServiceLoginItem

final class SMAppServiceLoginItem: LoginItemService {
    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    var registered: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
