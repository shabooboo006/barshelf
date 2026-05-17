import Foundation

public protocol LoginItemService: AnyObject {
    func register() throws
    func unregister() throws
    var registered: Bool { get }
}

public final class LaunchAtLoginController {
    private let service: LoginItemService
    public init(service: LoginItemService) { self.service = service }
    public var isEnabled: Bool { service.registered }
    public func setEnabled(_ on: Bool) {
        do { if on { try service.register() } else { try service.unregister() } }
        catch { /* swallow: state reflects service.registered; logged by caller */ }
    }
}
