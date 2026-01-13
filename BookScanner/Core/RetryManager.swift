import Foundation

/// Manages retry logic for operations that may fail
struct RetryManager {
    let maxAttempts: Int
    let delay: TimeInterval
    let backoffMultiplier: Double
    
    init(maxAttempts: Int = 3, delay: TimeInterval = 1.0, backoffMultiplier: Double = 2.0) {
        self.maxAttempts = maxAttempts
        self.delay = delay
        self.backoffMultiplier = backoffMultiplier
    }
    
    /// Execute an operation with retry logic
    func execute<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= backoffMultiplier
                }
            }
        }
        
        throw lastError ?? AppError.unknown(underlying: nil)
    }
    
    /// Execute with exponential backoff
    func executeWithBackoff<T>(
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await execute(operation: operation)
    }
}
