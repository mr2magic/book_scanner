import Foundation

struct AmazonBookInfo {
    let title: String?
    let author: String?
    let publisher: String?
    let price: String
    let url: String
}

/// Modern Amazon service with async/await and proper error handling
final class AmazonService: ObservableObject {
    private func getConfig() async -> AppConfiguration {
        await AppConfiguration.shared
    }
    private let retryManager: RetryManager
    private let urlSession: URLSession
    
    init(urlSession: URLSession = .shared, retryManager: RetryManager? = nil) {
        self.urlSession = urlSession
        self.retryManager = retryManager ?? RetryManager(maxAttempts: 3)
    }
    
    /// Lookup and validate book with async/await
    func lookupAndValidate(title: String, author: String) async throws -> AmazonBookInfo {
        return try await retryManager.execute {
            try await self.performLookup(title: title, author: author)
        }
    }
    
    /// Legacy completion handler support
    func lookupAndValidate(title: String, author: String, completion: @escaping (Result<AmazonBookInfo, AmazonServiceError>) -> Void) {
        Task {
            do {
                let info = try await lookupAndValidate(title: title, author: author)
                await MainActor.run {
                    completion(.success(info))
                }
            } catch {
                let amazonError = AmazonServiceError.from(error)
                await MainActor.run {
                    completion(.failure(amazonError))
                }
            }
        }
    }
    
    /// Legacy lookupBook method
    func lookupBook(title: String, author: String, completion: @escaping (Result<AmazonBookInfo, AmazonServiceError>) -> Void) {
        lookupAndValidate(title: title, author: author, completion: completion)
    }
    
    // MARK: - Private Methods
    
    private func performLookup(title: String, author: String) async throws -> AmazonBookInfo {
        let searchQuery = "\(title) \(author)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://www.amazon.com/s?k=\(searchQuery)") else {
            throw AppError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        let config = await getConfig()
        let timeout = await config.networkTimeout
        request.timeoutInterval = timeout
        
        do {
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw AppError.networkError(underlying: NSError(domain: "HTTPError", code: (response as? HTTPURLResponse)?.statusCode ?? 0))
            }
            
            guard let html = String(data: data, encoding: .utf8) else {
                throw AppError.invalidData
            }
            
            return parseAmazonResults(html: html, originalTitle: title, originalAuthor: author)
        } catch {
            if error is AppError {
                throw error
            }
            throw AppError.networkError(underlying: error)
        }
    }
    
    private func parseAmazonResults(html: String, originalTitle: String, originalAuthor: String) -> AmazonBookInfo {
        var title: String? = originalTitle
        var author: String? = originalAuthor
        var publisher: String? = nil
        var price = "N/A"
        var url = "https://www.amazon.com"
        
        // Extract title
        if let titleMatch = extractFirstMatch(in: html, pattern: #"<span[^>]*data-component-type="s-search-result"[^>]*>.*?<h2[^>]*>.*?<span[^>]*>(.*?)</span>"#, options: .dotMatchesLineSeparators) {
            title = cleanHTML(titleMatch)
        }
        
        // Extract author
        if let authorMatch = extractFirstMatch(in: html, pattern: #"<span[^>]*class="a-size-base[^"]*"[^>]*>by\s+([^<]+)</span>"#, options: .caseInsensitive) {
            author = cleanHTML(authorMatch)
        }
        
        // Extract publisher
        if let publisherMatch = extractFirstMatch(in: html, pattern: #"<span[^>]*class="a-size-base[^"]*"[^>]*>([^<]*Press[^<]*)</span>"#, options: .caseInsensitive) {
            publisher = cleanHTML(publisherMatch)
        }
        
        // Extract price
        if let priceMatch = extractFirstMatch(in: html, pattern: #"<span[^>]*class="a-price[^"]*"[^>]*>.*?<span[^>]*class="a-offscreen"[^>]*>([^<]+)</span>"#) {
            price = cleanHTML(priceMatch)
        }
        
        // Extract URL
        if let urlMatch = extractFirstMatch(in: html, pattern: #"<a[^>]*href="([^"]*)"[^>]*data-component-type="s-search-result""#) {
            let urlString = cleanHTML(urlMatch)
            if urlString.hasPrefix("/") {
                url = "https://www.amazon.com\(urlString)"
            } else if urlString.hasPrefix("http") {
                url = urlString
            }
        }
        
        return AmazonBookInfo(
            title: title,
            author: author,
            publisher: publisher,
            price: price,
            url: url
        )
    }
    
    private func extractFirstMatch(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1 else {
            return nil
        }
        
        return String(text[Range(match.range(at: 1), in: text)!])
    }
    
    private func cleanHTML(_ html: String) -> String {
        return html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum AmazonServiceError: Error {
    case invalidResponse
    case networkError(Error)
    case noResults
    case invalidURL
    
    static func from(_ error: Error) -> AmazonServiceError {
        if let appError = error as? AppError {
            switch appError {
            case .invalidURL:
                return .invalidURL
            case .networkError(let underlying):
                return .networkError(underlying)
            case .invalidData:
                return .invalidResponse
            default:
                return .noResults
            }
        }
        return .networkError(error)
    }
}
