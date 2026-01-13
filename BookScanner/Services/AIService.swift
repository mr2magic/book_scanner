import UIKit
import Vision
import CoreML

/// Modern AI service with async/await, error handling, and improved book detection
@MainActor
final class AIService: ObservableObject {
    private var config: AppConfiguration { AppConfiguration.shared }
    private let imageCache = ImageCache.shared
    
    /// Recognize books from image using async/await
    func recognizeBooks(from image: UIImage) async throws -> [Book] {
        // Step 1: Detect and correct image orientation for better recognition
        let orientedImage = detectAndCorrectOrientation(image: image)
        
        guard let cgImage = orientedImage.cgImage else {
            throw AppError.imageProcessingFailed
        }
        
        // Step 2: Try rectangle detection to isolate individual book spines
        do {
            let rectangles = try await detectRectangles(in: cgImage)
            
            if !rectangles.isEmpty {
                let bookSpines = groupRectanglesIntoBooks(rectangles)
                return try await extractTextFromBookSpines(bookSpines: bookSpines, cgImage: cgImage, image: orientedImage)
            }
        } catch {
            logError(error)
            // Fall through to text-based detection
        }
        
        // Step 3: Fallback to text-based detection (processes entire image)
        return try await processWithTextRecognition(cgImage: cgImage, image: orientedImage)
    }
    
    /// Legacy completion handler support
    func recognizeBooks(from image: UIImage, completion: @escaping ([Book]) -> Void) {
        Task {
            do {
                let books = try await recognizeBooks(from: image)
                await MainActor.run {
                    completion(books)
                }
            } catch {
                logError(error)
                await MainActor.run {
                    completion([])
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Detect and correct image orientation for vertical book spines
    private func detectAndCorrectOrientation(image: UIImage) -> UIImage {
        let isPortrait = image.size.height > image.size.width * 1.5
        
        // If image is very tall (portrait), text might be vertical
        // Rotate to make text horizontal for better OCR
        if isPortrait {
            return rotateImage(image: image, degrees: -90)
        }
        
        return image
    }
    
    /// Rotate image by degrees
    private func rotateImage(image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        let rotatedSize = CGRect(origin: .zero, size: image.size)
            .applying(CGAffineTransform(rotationAngle: radians))
            .integral.size
        
        UIGraphicsBeginImageContextWithOptions(rotatedSize, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        context.translateBy(x: rotatedSize.width / 2, y: rotatedSize.height / 2)
        context.rotate(by: radians)
        image.draw(in: CGRect(x: -image.size.width / 2, y: -image.size.height / 2, width: image.size.width, height: image.size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func detectRectangles(in cgImage: CGImage) async throws -> [VNRectangleObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.aiRecognitionFailed(reason: error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                continuation.resume(returning: observations)
            }
            
            request.minimumAspectRatio = 0.1
            request.maximumAspectRatio = 10.0
            request.minimumSize = 0.01
            request.minimumConfidence = 0.3
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            Task.detached(priority: .userInitiated) {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: AppError.aiRecognitionFailed(reason: error.localizedDescription))
                }
            }
        }
    }
    
    private func groupRectanglesIntoBooks(_ rectangles: [VNRectangleObservation]) -> [[VNRectangleObservation]] {
        let sorted = rectangles.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        
        var bookGroups: [[VNRectangleObservation]] = []
        var currentGroup: [VNRectangleObservation] = []
        
        for rect in sorted {
            if currentGroup.isEmpty {
                currentGroup.append(rect)
            } else {
                let lastRect = currentGroup.last!
                let xDistance = abs(rect.boundingBox.minX - lastRect.boundingBox.maxX)
                
                if xDistance < 0.05 {
                    currentGroup.append(rect)
                } else {
                    bookGroups.append(currentGroup)
                    currentGroup = [rect]
                }
            }
        }
        
        if !currentGroup.isEmpty {
            bookGroups.append(currentGroup)
        }
        
        return bookGroups
    }
    
    private func extractTextFromBookSpines(bookSpines: [[VNRectangleObservation]], cgImage: CGImage, image: UIImage) async throws -> [Book] {
        return try await withThrowingTaskGroup(of: Book?.self) { group in
            var books: [Book] = []
            
            for spineGroup in bookSpines {
                let combinedBox = combineBoundingBoxes(spineGroup)
                
                guard let croppedImage = cropImage(cgImage: cgImage, boundingBox: combinedBox, imageSize: image.size) else {
                    continue
                }
                
                group.addTask { @MainActor in
                    let textData = try? await self.recognizeTextInRegion(cgImage: croppedImage)
                    if let textData = textData, !textData.isEmpty {
                        return self.parseBookFromText(textData, image: image)
                    }
                    return nil
                }
            }
            
            for try await book in group {
                if let book = book {
                    books.append(book)
                }
            }
            
            return books
        }
    }
    
    private func combineBoundingBoxes(_ rectangles: [VNRectangleObservation]) -> CGRect {
        guard !rectangles.isEmpty else { return .zero }
        
        var minX: CGFloat = 1.0
        var minY: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var maxY: CGFloat = 0.0
        
        for rect in rectangles {
            minX = min(minX, rect.boundingBox.minX)
            minY = min(minY, rect.boundingBox.minY)
            maxX = max(maxX, rect.boundingBox.maxX)
            maxY = max(maxY, rect.boundingBox.maxY)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    private func cropImage(cgImage: CGImage, boundingBox: CGRect, imageSize: CGSize) -> CGImage? {
        let x = boundingBox.minX * imageSize.width
        let y = (1.0 - boundingBox.maxY) * imageSize.height
        let width = boundingBox.width * imageSize.width
        let height = boundingBox.height * imageSize.height
        
        let cropRect = CGRect(x: x, y: y, width: width, height: height)
        return cgImage.cropping(to: cropRect)
    }
    
    private func recognizeTextInRegion(cgImage: CGImage) async throws -> [(text: String, confidence: Float)] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: AppError.aiRecognitionFailed(reason: error.localizedDescription))
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                var textData: [(text: String, confidence: Float)] = []
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first,
                          topCandidate.confidence > self.config.aiConfidenceThreshold else {
                        continue
                    }
                    
                    let text = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !text.isEmpty && text.count > 1 {
                        textData.append((text: text, confidence: topCandidate.confidence))
                    }
                }
                
                continuation.resume(returning: textData)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            
            if #available(iOS 16.0, *) {
                request.automaticallyDetectsLanguage = true
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            Task.detached(priority: .userInitiated) {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: AppError.aiRecognitionFailed(reason: error.localizedDescription))
                }
            }
        }
    }
    
    private func processWithTextRecognition(cgImage: CGImage, image: UIImage) async throws -> [Book] {
        let textData = try await recognizeTextInRegion(cgImage: cgImage)
        return parseBooksFromTextLines(textData.map { $0.text }, image: image)
    }
    
    private func parseBookFromText(_ textData: [(text: String, confidence: Float)], image: UIImage) -> Book? {
        guard !textData.isEmpty else { return nil }
        let texts = textData.map { $0.text }
        return parseBooksFromTextLines(texts, image: image).first
    }
    
    private func parseBooksFromTextLines(_ textLines: [String], image: UIImage) -> [Book] {
        guard !textLines.isEmpty else { return [] }
        
        let cleanedLines = textLines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                line.count > 2 &&
                !line.allSatisfy { $0.isNumber || $0.isPunctuation } &&
                !line.lowercased().contains("no results") &&
                !line.lowercased().contains("check each product")
            }
        
        guard !cleanedLines.isEmpty else { return [] }
        
        var books: [Book] = []
        var i = 0
        
        while i < cleanedLines.count {
            var title = ""
            var author: String? = nil
            var publisher: String? = nil
            
            if let parsed = parseBookLine(cleanedLines[i]) {
                title = parsed.title
                author = parsed.author
                publisher = parsed.publisher
                i += 1
            } else {
                title = cleanedLines[i]
                i += 1
                
                // Collect author lines (may be multiple authors)
                var authorLines: [String] = []
                
                while i < cleanedLines.count {
                    let nextLine = cleanedLines[i]
                    
                    // Check if it's a publisher - if so, stop collecting authors
                    if isPublisherName(nextLine) {
                        publisher = nextLine
                        i += 1
                        break
                    }
                    
                    // Check if it's likely a title (new book) - if so, stop
                    if isLikelyTitle(nextLine) && nextLine.count > title.count {
                        break
                    }
                    
                    // Check if this line contains author indicators (AND, &, etc.)
                    if containsAuthorIndicators(nextLine) || !isPublisherName(nextLine) {
                        authorLines.append(nextLine)
                        i += 1
                        
                        // If we have 2-3 author lines, likely we have all authors
                        // Check next line to see if it's a publisher
                        if i < cleanedLines.count && isPublisherName(cleanedLines[i]) {
                            publisher = cleanedLines[i]
                            i += 1
                            break
                        }
                        
                        // Limit to 3 author lines to avoid collecting too much
                        if authorLines.count >= 3 {
                            break
                        }
                    } else {
                        break
                    }
                }
                
                // Combine author lines, preserving original formatting
                if !authorLines.isEmpty {
                    author = combineAuthors(authorLines)
                }
            }
            
            if !title.isEmpty && title.count > 2 {
                books.append(createBook(
                    title: title,
                    author: author ?? "Unknown",
                    publisher: publisher,
                    image: image
                ))
            }
        }
        
        return books
    }
    
    private func parseBookLine(_ line: String) -> (title: String, author: String?, publisher: String?)? {
        // Pattern 1: "Title | Author | Publisher"
        if let match = try? NSRegularExpression(pattern: #"^(.+?)\s*[|•]\s*(.+?)(?:\s*[|•]\s*(.+))?$"#)
            .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            
            let title = String(line[Range(match.range(at: 1), in: line)!]).trimmingCharacters(in: .whitespaces)
            let author = match.numberOfRanges > 2 ? String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces) : nil
            let publisher = match.numberOfRanges > 3 ? String(line[Range(match.range(at: 3), in: line)!]).trimmingCharacters(in: .whitespaces) : nil
            
            if !title.isEmpty {
                return (title, author, publisher)
            }
        }
        
        // Pattern 2: "Title - Author - Publisher"
        if let match = try? NSRegularExpression(pattern: #"^(.+?)\s*-\s*(.+?)(?:\s*-\s*(.+))?$"#)
            .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            
            let title = String(line[Range(match.range(at: 1), in: line)!]).trimmingCharacters(in: .whitespaces)
            let author = match.numberOfRanges > 2 ? String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces) : nil
            let publisher = match.numberOfRanges > 3 ? String(line[Range(match.range(at: 3), in: line)!]).trimmingCharacters(in: .whitespaces) : nil
            
            if !title.isEmpty {
                return (title, author, publisher)
            }
        }
        
        // Pattern 3: "Title by Author" (handles multiple authors: "Title by Author1 AND Author2")
        if let match = try? NSRegularExpression(pattern: #"^(.+?)\s+by\s+(.+)$"#, options: .caseInsensitive)
            .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            
            let title = String(line[Range(match.range(at: 1), in: line)!]).trimmingCharacters(in: .whitespaces)
            // Preserve full author string as-is (may contain multiple authors with AND, &, etc.)
            let author = String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces)
            
            if !title.isEmpty {
                return (title, author, nil)
            }
        }
        
        // Pattern 4: "Title, Author" (handles multiple authors: "Title, Author1 AND Author2")
        if let match = try? NSRegularExpression(pattern: #"^(.+?),\s*(.+)$"#)
            .firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            
            let title = String(line[Range(match.range(at: 1), in: line)!]).trimmingCharacters(in: .whitespaces)
            // Preserve full author string as-is (may contain multiple authors)
            let author = String(line[Range(match.range(at: 2), in: line)!]).trimmingCharacters(in: .whitespaces)
            
            if !title.isEmpty {
                return (title, author, nil)
            }
        }
        
        return nil
    }
    
    private func isPublisherName(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        let publisherKeywords = ["press", "publishing", "books", "publishers", "inc", "llc", "ltd", "company", "house"]
        
        return publisherKeywords.contains { lowercased.contains($0) } ||
               (text.count < 30 && text.count > 2 && !text.contains(" ") && text == text.uppercased()) ||
               text.hasSuffix("PRESS") || text.hasSuffix("BOOKS")
    }
    
    private func isLikelyTitle(_ text: String) -> Bool {
        return text.count > 15 && text.contains(" ")
    }
    
    /// Check if a line contains indicators of multiple authors
    private func containsAuthorIndicators(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        return lowercased.contains(" and ") ||
               lowercased.contains(" & ") ||
               lowercased.contains(", ") ||
               lowercased.contains(" AND ") ||
               lowercased.contains(" & ")
    }
    
    /// Combine multiple author lines into a single author string, preserving formatting
    private func combineAuthors(_ authorLines: [String]) -> String {
        guard !authorLines.isEmpty else { return "" }
        
        // If single line, return as-is (may already contain multiple authors)
        if authorLines.count == 1 {
            return authorLines[0].trimmingCharacters(in: .whitespaces)
        }
        
        // Multiple lines - combine with appropriate separator
        // Check if lines already contain author separators
        let combined = authorLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // If any line contains "AND" or "&", preserve that formatting
        if combined.contains(where: { $0.uppercased().contains(" AND ") || $0.contains(" & ") }) {
            return combined.joined(separator: " ")
        }
        
        // Otherwise, join with " AND " for clarity
        return combined.joined(separator: " AND ")
    }
    
    private func createBook(title: String, author: String, publisher: String?, image: UIImage) -> Book {
        return Book(
            title: title,
            author: author,
            publisher: publisher,
            isbn: nil,
            dateAdded: Date(),
            imageData: image.jpegData(compressionQuality: config.imageCompressionQuality),
            amazonPrice: nil,
            amazonURL: nil,
            notes: nil
        )
    }
    
    // MARK: - Logging
    
    private func logError(_ error: Error) {
        if #available(iOS 14.0, *) {
            AppLogger.log("AI Error: \(error.localizedDescription)", level: .error, category: AppLogger.ai)
        } else {
            SimpleLogger.log("AI Error: \(error.localizedDescription)", level: "ERROR")
        }
    }
}
