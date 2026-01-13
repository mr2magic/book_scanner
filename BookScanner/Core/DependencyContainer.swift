import Foundation

/// Dependency injection container for managing service dependencies
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private var services: [String: Any] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// Register a service
    func register<T>(_ service: T, for type: T.Type) {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        services[key] = service
    }
    
    /// Resolve a service
    func resolve<T>(_ type: T.Type) -> T? {
        lock.lock()
        defer { lock.unlock() }
        let key = String(describing: type)
        return services[key] as? T
    }
    
    /// Resolve a service or create default
    func resolveOrCreate<T>(_ type: T.Type, factory: () -> T) -> T {
        if let service = resolve(type) {
            return service
        }
        let service = factory()
        register(service, for: type)
        return service
    }
}

/// Service protocol for dependency injection
protocol Service {
    associatedtype ServiceType
    static var shared: ServiceType { get }
}
