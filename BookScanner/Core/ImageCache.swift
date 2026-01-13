import UIKit
import Foundation

/// Thread-safe image cache using actor for concurrency safety
actor ImageCache {
    static let shared = ImageCache()
    
    private var cache: [String: UIImage] = [:]
    private var cacheSize: Int = 0
    private let maxCacheSize: Int
    
    private init(maxCacheSize: Int = 100 * 1024 * 1024) { // 100MB default
        self.maxCacheSize = maxCacheSize
    }
    
    /// Get image from cache
    func get(key: String) -> UIImage? {
        return cache[key]
    }
    
    /// Store image in cache
    func set(_ image: UIImage, forKey key: String) {
        let imageSize = estimateImageSize(image)
        
        // Evict if needed
        while cacheSize + imageSize > maxCacheSize && !cache.isEmpty {
            if let (oldestKey, _) = cache.first {
                remove(key: oldestKey)
            }
        }
        
        cache[key] = image
        cacheSize += imageSize
    }
    
    /// Remove image from cache
    func remove(key: String) {
        if let image = cache.removeValue(forKey: key) {
            cacheSize -= estimateImageSize(image)
        }
    }
    
    /// Clear all cache
    func clear() {
        cache.removeAll()
        cacheSize = 0
    }
    
    /// Get current cache size
    func getCacheSize() -> Int {
        return cacheSize
    }
    
    private func estimateImageSize(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.width * cgImage.height * 4 // 4 bytes per pixel (RGBA)
    }
}

/// Image cache key generator
struct ImageCacheKey {
    static func generate(for image: UIImage) -> String {
        // Use image hash or data hash for key
        if let data = image.jpegData(compressionQuality: 1.0) {
            return data.hashValue.description
        }
        return UUID().uuidString
    }
    
    static func generate(for bookId: UUID) -> String {
        return "book_\(bookId.uuidString)"
    }
}
