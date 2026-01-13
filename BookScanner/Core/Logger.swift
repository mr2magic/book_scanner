import Foundation
import OSLog

/// Centralized logging system using OSLog for production-ready logging
@available(iOS 14.0, *)
enum AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bookscanner.app"
    
    static let general = Logger(subsystem: subsystem, category: "general")
    static let ocr = Logger(subsystem: subsystem, category: "ocr")
    static let ai = Logger(subsystem: subsystem, category: "ai")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let database = Logger(subsystem: subsystem, category: "database")
    static let ui = Logger(subsystem: subsystem, category: "ui")
    static let auth = Logger(subsystem: subsystem, category: "authentication")
    
    /// Log levels for different severity
    enum LogLevel {
        case debug, info, notice, error, fault
    }
    
    static func log(_ message: String, level: LogLevel = .info, category: Logger = general) {
        switch level {
        case .debug:
            category.debug("\(message)")
        case .info:
            category.info("\(message)")
        case .notice:
            category.notice("\(message)")
        case .error:
            category.error("\(message)")
        case .fault:
            category.fault("\(message)")
        }
    }
}

/// Fallback logger for iOS 13
struct SimpleLogger {
    static func log(_ message: String, level: String = "INFO") {
        print("[\(level)] \(Date()): \(message)")
    }
}
