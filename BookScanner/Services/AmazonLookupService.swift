import Foundation

struct AmazonBookMatch {
    let title: String
    let author: String
    let publisher: String?
    let isbn: String?
    let price: String
    let url: String
    let matchScore: Double // 0.0 to 1.0, higher is better match
}

enum AmazonLookupError: Error {
    case invalidCredentials
    case networkError(Error)
    case noMatch
    case invalidResponse
}

class AmazonLookupService: ObservableObject {
    private let apiKey: String
    private let secretKey: String
    private let associateTag: String
    
    init(apiKey: String = "", secretKey: String = "", associateTag: String = "") {
        self.apiKey = apiKey
        self.secretKey = secretKey
        self.associateTag = associateTag
    }
    
    // Accurate lookup by title and author matching
    func lookupBook(title: String, author: String, completion: @escaping (Result<AmazonBookMatch, AmazonLookupError>) -> Void) {
        // Validate credentials
        guard !apiKey.isEmpty, !secretKey.isEmpty, !associateTag.isEmpty else {
            completion(.failure(.invalidCredentials))
            return
        }
        
        // TODO: Implement Amazon Product Advertising API 5.0
        // This is a stub for accurate title/author matching
        // Will use SearchItems operation with:
        // - Keywords: title + author
        // - SearchIndex: Books
        // - ResponseGroup: ItemAttributes,Offers
        // - Match title and author similarity scoring
        
        // For now, use web search as fallback
        performWebSearch(title: title, author: author) { result in
            switch result {
            case .success(let match):
                completion(.success(match))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Web search fallback with title/author matching
    private func performWebSearch(title: String, author: String, completion: @escaping (Result<AmazonBookMatch, AmazonLookupError>) -> Void) {
        let searchQuery = "\(title) \(author)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://www.amazon.com/s?k=\(searchQuery)&i=stripbooks") else {
            completion(.failure(.invalidResponse))
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                completion(.failure(.invalidResponse))
                return
            }
            
            // Parse and match results
            if let match = self.parseAndMatch(html: html, searchTitle: title, searchAuthor: author) {
                completion(.success(match))
            } else {
                completion(.failure(.noMatch))
            }
        }.resume()
    }
    
    // Parse HTML and match title/author with similarity scoring
    private func parseAndMatch(html: String, searchTitle: String, searchAuthor: String) -> AmazonBookMatch? {
        // Extract potential book results
        // Match title and author with similarity scoring
        // Return best match with highest score
        
        // TODO: Implement proper HTML parsing and similarity matching
        // For now, return placeholder
        
        let url = "https://www.amazon.com/s?k=\(searchTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        
        // Simple matching - in production, use proper API
        return AmazonBookMatch(
            title: searchTitle,
            author: searchAuthor,
            publisher: nil,
            isbn: nil,
            price: "Check Amazon",
            url: url,
            matchScore: 0.5 // Placeholder score
        )
    }
    
    // Calculate similarity score between two strings
    private func similarityScore(_ str1: String, _ str2: String) -> Double {
        let s1 = str1.lowercased().trimmingCharacters(in: .whitespaces)
        let s2 = str2.lowercased().trimmingCharacters(in: .whitespaces)
        
        if s1 == s2 { return 1.0 }
        if s1.contains(s2) || s2.contains(s1) { return 0.8 }
        
        // Simple word overlap scoring
        let words1 = Set(s1.components(separatedBy: .whitespaces))
        let words2 = Set(s2.components(separatedBy: .whitespaces))
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
}
