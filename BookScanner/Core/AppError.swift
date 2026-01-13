import Foundation

/// Comprehensive error types for the application
enum AppError: LocalizedError {
    case networkError(underlying: Error)
    case invalidData
    case invalidURL
    case imageProcessingFailed
    case ocrFailed(reason: String)
    case aiRecognitionFailed(reason: String)
    case databaseError(underlying: Error)
    case validationFailed(field: String, message: String)
    case authenticationFailed(reason: String)
    case fileSystemError(underlying: Error)
    case unknown(underlying: Error?)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data received"
        case .invalidURL:
            return "Invalid URL"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .ocrFailed(let reason):
            return "OCR failed: \(reason)"
        case .aiRecognitionFailed(let reason):
            return "AI recognition failed: \(reason)"
        case .databaseError(let error):
            return "Database error: \(error.localizedDescription)"
        case .validationFailed(let field, let message):
            return "Validation failed for \(field): \(message)"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .fileSystemError(let error):
            return "File system error: \(error.localizedDescription)"
        case .unknown(let error):
            return error?.localizedDescription ?? "Unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .invalidData, .invalidURL:
            return "Please try again with a different input."
        case .imageProcessingFailed, .ocrFailed, .aiRecognitionFailed:
            return "Please try with a clearer image or better lighting."
        case .databaseError:
            return "Please restart the app. If the problem persists, contact support."
        case .validationFailed:
            return "Please correct the input and try again."
        case .authenticationFailed:
            return "Please try authenticating again."
        case .fileSystemError:
            return "Please check available storage space."
        case .unknown:
            return "Please try again. If the problem persists, contact support."
        }
    }
}

/// Result type alias for cleaner error handling
typealias AppResult<T> = Result<T, AppError>
