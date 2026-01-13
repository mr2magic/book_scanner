import UIKit
import BackgroundTasks

/// Manages background tasks for long-running operations
@MainActor
final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()
    
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    
    private init() {}
    
    /// Start a background task
    func beginBackgroundTask(name: String = "BookScannerTask") -> Bool {
        guard backgroundTaskID == .invalid else {
            return false // Already have a task
        }
        
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            self?.endBackgroundTask()
        }
        
        return backgroundTaskID != .invalid
    }
    
    /// End the current background task
    func endBackgroundTask() {
        guard backgroundTaskID != .invalid else {
            return
        }
        
        let taskID = backgroundTaskID
        backgroundTaskID = .invalid
        UIApplication.shared.endBackgroundTask(taskID)
    }
    
    /// Execute a task with background task management
    func executeWithBackgroundTask<T>(
        name: String = "BookScannerTask",
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let hasTask = beginBackgroundTask(name: name)
        defer {
            if hasTask {
                endBackgroundTask()
            }
        }
        
        return try await operation()
    }
}
