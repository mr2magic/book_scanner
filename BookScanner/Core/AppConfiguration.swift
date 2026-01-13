import Foundation

/// Centralized configuration management
@MainActor
final class AppConfiguration: ObservableObject {
    static let shared = AppConfiguration()
    
    @Published var ocrConfidenceThreshold: Float = 0.3
    @Published var aiConfidenceThreshold: Float = 0.5
    @Published var maxImageSize: CGSize = CGSize(width: 2048, height: 2048)
    @Published var imageCompressionQuality: CGFloat = 0.8
    @Published var enableCaching: Bool = true
    @Published var cacheSizeLimit: Int = 100 * 1024 * 1024 // 100MB
    @Published var networkTimeout: TimeInterval = 30.0
    @Published var maxRetryAttempts: Int = 3
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadConfiguration()
    }
    
    private func loadConfiguration() {
        ocrConfidenceThreshold = userDefaults.object(forKey: "ocrConfidenceThreshold") as? Float ?? 0.3
        aiConfidenceThreshold = userDefaults.object(forKey: "aiConfidenceThreshold") as? Float ?? 0.5
        imageCompressionQuality = CGFloat(userDefaults.object(forKey: "imageCompressionQuality") as? Double ?? 0.8)
        enableCaching = userDefaults.object(forKey: "enableCaching") as? Bool ?? true
        networkTimeout = userDefaults.object(forKey: "networkTimeout") as? TimeInterval ?? 30.0
        maxRetryAttempts = userDefaults.object(forKey: "maxRetryAttempts") as? Int ?? 3
    }
    
    func saveConfiguration() {
        userDefaults.set(ocrConfidenceThreshold, forKey: "ocrConfidenceThreshold")
        userDefaults.set(aiConfidenceThreshold, forKey: "aiConfidenceThreshold")
        userDefaults.set(Double(imageCompressionQuality), forKey: "imageCompressionQuality")
        userDefaults.set(enableCaching, forKey: "enableCaching")
        userDefaults.set(networkTimeout, forKey: "networkTimeout")
        userDefaults.set(maxRetryAttempts, forKey: "maxRetryAttempts")
    }
}
