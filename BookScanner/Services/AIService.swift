import UIKit
import Vision
import CoreML

/// Sendable book data for passing through TaskGroup
private struct BookData: Sendable {
    let title: String
    let author: String
    let publisher: String?
    let imageData: Data?
}

/// Modern AI service with async/await, error handling, and improved book detection
@MainActor
final class AIService: ObservableObject {
    private var config: AppConfiguration { AppConfiguration.shared }
    private let imageCache = ImageCache.shared
    
    /// Published progress for UI updates
    @Published var scanProgress: ScanProgress?
    
    /// Recognize books from image using async/await
    func recognizeBooks(from image: UIImage, useFullImageScan: Bool = false) async throws -> [Book] {
        // Reset progress
        scanProgress = nil
        
        if #available(iOS 14.0, *) {
            AppLogger.log("Starting AI recognition - useFullImageScan: \(useFullImageScan)", level: .info, category: AppLogger.ai)
        } else {
            SimpleLogger.log("Starting AI recognition - useFullImageScan: \(useFullImageScan)")
        }
        
        // Step 1: Detect and correct image orientation for better recognition
        scanProgress = ScanProgress(current: 0, total: 1, stage: "Preparing image")
        let orientedImage = detectAndCorrectOrientation(image: image)
        
        guard let cgImage = orientedImage.cgImage else {
            throw AppError.imageProcessingFailed
        }
        
        // If explicitly requested, skip isolation and use full image
        if useFullImageScan {
            if #available(iOS 14.0, *) {
                AppLogger.log("Using full image scan (bypassing book isolation)", level: .info, category: AppLogger.ai)
            } else {
                SimpleLogger.log("Using full image scan (bypassing book isolation)")
            }
            scanProgress = ScanProgress(current: 0, total: 1, stage: "Processing full image")
            let books = try await processWithTextRecognition(cgImage: cgImage, image: orientedImage)
            scanProgress = nil
            return books
        }
        
        // Step 2: Try rectangle detection to isolate individual book spines
        scanProgress = ScanProgress(current: 0, total: 1, stage: "Detecting book spines")
        do {
            let rectangles = try await detectRectangles(in: cgImage)
            
            if #available(iOS 14.0, *) {
                AppLogger.log("Rectangle detection found \(rectangles.count) rectangles", level: .info, category: AppLogger.ai)
            } else {
                SimpleLogger.log("Rectangle detection found \(rectangles.count) rectangles")
            }
            
            if !rectangles.isEmpty {
                let bookSpines = groupRectanglesIntoBooks(rectangles)
                if #available(iOS 14.0, *) {
                    AppLogger.log("Grouped into \(bookSpines.count) book spines", level: .info, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("Grouped into \(bookSpines.count) book spines")
                }
                
                let books = try await extractTextFromBookSpines(bookSpines: bookSpines, cgImage: cgImage, image: orientedImage)
                
                if #available(iOS 14.0, *) {
                    AppLogger.log("Extracted \(books.count) books from isolated spines", level: .info, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("Extracted \(books.count) books from isolated spines")
                }
                
                // If no books found from isolation, fall back to full image
                if books.isEmpty {
                    if #available(iOS 14.0, *) {
                        AppLogger.log("No books found from isolation, falling back to full image scan", level: .info, category: AppLogger.ai)
                    } else {
                        SimpleLogger.log("No books found from isolation, falling back to full image scan")
                    }
                    scanProgress = ScanProgress(current: 0, total: 1, stage: "Processing full image")
                    let fallbackBooks = try await processWithTextRecognition(cgImage: cgImage, image: orientedImage)
                    scanProgress = nil
                    return fallbackBooks
                }
                
                scanProgress = nil
                return books
            } else {
                if #available(iOS 14.0, *) {
                    AppLogger.log("No rectangles detected, falling back to text-based detection", level: .info, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("No rectangles detected, falling back to text-based detection")
                }
            }
        } catch {
            logError(error)
            if #available(iOS 14.0, *) {
                AppLogger.log("Rectangle detection error: \(error.localizedDescription), falling back to full image", level: .error, category: AppLogger.ai)
            } else {
                SimpleLogger.log("Rectangle detection error: \(error.localizedDescription), falling back to full image")
            }
            // Fall through to text-based detection
        }
        
        // Step 3: Fallback to text-based detection (processes entire image)
        scanProgress = ScanProgress(current: 0, total: 1, stage: "Processing full image")
        let books = try await processWithTextRecognition(cgImage: cgImage, image: orientedImage)
        
        if #available(iOS 14.0, *) {
            AppLogger.log("Fallback AI extracted \(books.count) books from full image", level: .info, category: AppLogger.ai)
        } else {
            SimpleLogger.log("Fallback AI extracted \(books.count) books from full image")
        }
        
        scanProgress = nil
        return books
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
            
            // Optimize for book spines: tall thin rectangles
            request.minimumAspectRatio = 0.05  // Allow very tall thin rectangles
            request.maximumAspectRatio = 20.0  // Allow wider rectangles too
            request.minimumSize = 0.005  // Smaller minimum to catch more books
            request.minimumConfidence = 0.2  // Lower confidence to catch more books
            request.maximumObservations = 50  // Allow up to 50 rectangles (books)
            
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
        guard !rectangles.isEmpty else { return [] }
        
        // Sort by X position (left to right)
        let sorted = rectangles.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
        
        // Each rectangle represents a potential book spine
        // Group only if rectangles significantly overlap (same book)
        // Otherwise, treat each as a separate book
        var bookGroups: [[VNRectangleObservation]] = []
        var processed: Set<Int> = []
        
        for (index, rect) in sorted.enumerated() {
            if processed.contains(index) {
                continue
            }
            
            var group: [VNRectangleObservation] = [rect]
            processed.insert(index)
            
            // Find overlapping or very close rectangles (same book spine)
            for (otherIndex, otherRect) in sorted.enumerated() {
                if processed.contains(otherIndex) || index == otherIndex {
                    continue
                }
                
                // Check if rectangles overlap significantly (same book)
                let overlap = calculateOverlap(rect.boundingBox, otherRect.boundingBox)
                let xDistance = abs(rect.boundingBox.minX - otherRect.boundingBox.minX)
                
                // If rectangles overlap by more than 30% or are very close horizontally (< 0.02), they're the same book
                if overlap > 0.3 || (xDistance < 0.02 && abs(rect.boundingBox.midY - otherRect.boundingBox.midY) < 0.1) {
                    group.append(otherRect)
                    processed.insert(otherIndex)
                }
            }
            
            bookGroups.append(group)
        }
        
        return bookGroups
    }
    
    /// Calculate overlap percentage between two rectangles
    private func calculateOverlap(_ rect1: CGRect, _ rect2: CGRect) -> CGFloat {
        let intersection = rect1.intersection(rect2)
        if intersection.isNull {
            return 0.0
        }
        
        let intersectionArea = intersection.width * intersection.height
        let rect1Area = rect1.width * rect1.height
        let rect2Area = rect2.width * rect2.height
        let unionArea = rect1Area + rect2Area - intersectionArea
        
        return unionArea > 0 ? intersectionArea / unionArea : 0.0
    }
    
    private func extractTextFromBookSpines(bookSpines: [[VNRectangleObservation]], cgImage: CGImage, image: UIImage) async throws -> [Book] {
        let totalBooks = bookSpines.count
        
        if #available(iOS 14.0, *) {
            AppLogger.log("Starting sequential processing of \(totalBooks) books", level: .info, category: AppLogger.ai)
        } else {
            SimpleLogger.log("Starting sequential processing of \(totalBooks) books")
        }
        
        // Sort books by position: top to bottom, then left to right
        let sortedSpines = bookSpines.sorted { spine1, spine2 in
            let box1 = combineBoundingBoxes(spine1)
            let box2 = combineBoundingBoxes(spine2)
            
            // First sort by Y (top to bottom)
            if abs(box1.midY - box2.midY) > 0.05 {
                return box1.midY < box2.midY
            }
            // Then by X (left to right)
            return box1.minX < box2.minX
        }
        
        let imageData = image.jpegData(compressionQuality: config.imageCompressionQuality)
        var books: [Book] = []
        var failedBooks: [Int] = []
        
        // Process sequentially to ensure proper ordering and error tracking
        for (index, spineGroup) in sortedSpines.enumerated() {
            let bookNumber = index + 1
            
            await MainActor.run {
                self.scanProgress = ScanProgress(current: index, total: totalBooks, stage: "Processing book \(bookNumber) of \(totalBooks)")
            }
            
            // Get bounding box for this book
            let combinedBox = combineBoundingBoxes(spineGroup)
            
            if #available(iOS 14.0, *) {
                AppLogger.log("Book \(bookNumber): Bounding box = \(combinedBox)", level: .debug, category: AppLogger.ai)
            }
            
            // Validate bounding box
            guard combinedBox.width > 0 && combinedBox.height > 0,
                  combinedBox.minX >= 0 && combinedBox.minY >= 0,
                  combinedBox.maxX <= 1.0 && combinedBox.maxY <= 1.0 else {
                if #available(iOS 14.0, *) {
                    AppLogger.log("Book \(bookNumber): Invalid bounding box - \(combinedBox)", level: .error, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("Book \(bookNumber): Invalid bounding box - \(combinedBox)")
                }
                failedBooks.append(bookNumber)
                continue
            }
            
            // Crop image to this book's region
            guard let croppedImage = cropImage(cgImage: cgImage, boundingBox: combinedBox, imageSize: image.size) else {
                if #available(iOS 14.0, *) {
                    AppLogger.log("Book \(bookNumber): Failed to crop image", level: .error, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("Book \(bookNumber): Failed to crop image")
                }
                failedBooks.append(bookNumber)
                continue
            }
            
            // Process this individual book spine
            do {
                let textData = try await recognizeTextInRegion(cgImage: croppedImage)
                
                if #available(iOS 14.0, *) {
                    AppLogger.log("Book \(bookNumber): Extracted \(textData.count) text lines", level: .debug, category: AppLogger.ai)
                }
                
                if !textData.isEmpty {
                    // Parse all books from this spine
                    let parsedBooks = parseBooksFromTextLines(textData.map { $0.text }, image: image)
                    
                    if let firstBook = parsedBooks.first {
                        // Successfully parsed book
                        let book = createBook(
                            title: firstBook.title,
                            author: firstBook.author,
                            publisher: firstBook.publisher,
                            image: image
                        )
                        books.append(book)
                        
                        if #available(iOS 14.0, *) {
                            AppLogger.log("Book \(bookNumber): Successfully identified - '\(firstBook.title)' by \(firstBook.author)", level: .info, category: AppLogger.ai)
                        } else {
                            SimpleLogger.log("Book \(bookNumber): Successfully identified - '\(firstBook.title)' by \(firstBook.author)")
                        }
                    } else {
                        // Text found but couldn't parse - create book from first line
                        let firstText = textData[0].text
                        if firstText.count > 2 {
                            let book = createBook(
                                title: firstText,
                                author: "Unknown",
                                publisher: nil,
                                image: image
                            )
                            books.append(book)
                            
                            if #available(iOS 14.0, *) {
                                AppLogger.log("Book \(bookNumber): Created from text - '\(firstText)'", level: .info, category: AppLogger.ai)
                            } else {
                                SimpleLogger.log("Book \(bookNumber): Created from text - '\(firstText)'")
                            }
                        } else {
                            if #available(iOS 14.0, *) {
                                AppLogger.log("Book \(bookNumber): Text too short to create book", level: .info, category: AppLogger.ai)
                            } else {
                                SimpleLogger.log("Book \(bookNumber): Text too short to create book")
                            }
                            failedBooks.append(bookNumber)
                        }
                    }
                } else {
                    if #available(iOS 14.0, *) {
                        AppLogger.log("Book \(bookNumber): No text detected in cropped region", level: .info, category: AppLogger.ai)
                    } else {
                        SimpleLogger.log("Book \(bookNumber): No text detected in cropped region")
                    }
                    failedBooks.append(bookNumber)
                }
            } catch {
                if #available(iOS 14.0, *) {
                    AppLogger.log("Book \(bookNumber): Error processing - \(error.localizedDescription)", level: .error, category: AppLogger.ai)
                } else {
                    SimpleLogger.log("Book \(bookNumber): Error processing - \(error.localizedDescription)")
                }
                failedBooks.append(bookNumber)
            }
        }
        
        await MainActor.run {
            self.scanProgress = nil
        }
        
        if #available(iOS 14.0, *) {
            AppLogger.log("Sequential processing complete: \(books.count) books found, \(failedBooks.count) failed (books: \(failedBooks))", level: .info, category: AppLogger.ai)
        } else {
            SimpleLogger.log("Sequential processing complete: \(books.count) books found, \(failedBooks.count) failed (books: \(failedBooks))")
        }
        
        return books
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
        
        // If we have text observations, try to segment by position
        // Group text by vertical position to identify individual books
        let books = segmentBooksByTextPosition(textData: textData, image: image)
        
        // If segmentation didn't work well, fall back to line-based parsing
        if books.count <= 1 && textData.count > 3 {
            return parseBooksFromTextLines(textData.map { $0.text }, image: image)
        }
        
        return books
    }
    
    /// Segment books by analyzing text positions (for when rectangle detection fails)
    private func segmentBooksByTextPosition(textData: [(text: String, confidence: Float)], image: UIImage) -> [Book] {
        guard textData.count > 1 else {
            // Single text item - create one book
            if let first = textData.first, first.text.count > 2 {
                return [createBook(title: first.text, author: "Unknown", publisher: nil, image: image)]
            }
            return []
        }
        
        // Use the existing line-based parser which handles multiple books
        // The parser will intelligently segment books based on text patterns
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
            if let parsed = parseBookLine(cleanedLines[i]) {
                // Single line contains all info
                books.append(createBook(
                    title: parsed.title,
                    author: parsed.author ?? "Unknown",
                    publisher: parsed.publisher,
                    image: image
                ))
                i += 1
            } else {
                // Block-based parsing: isolate title, author, and publisher blocks
                let blocks = isolateBlocks(from: cleanedLines, startingAt: i)
                
                // Process each block individually for multi-line content
                let title = processTitleBlock(blocks.title)
                let author = processAuthorBlock(blocks.author)
                let publisher = processPublisherBlock(blocks.publisher)
                
                if !title.isEmpty && title.count > 2 {
                    books.append(createBook(
                        title: title,
                        author: author ?? "Unknown",
                        publisher: publisher,
                        image: image
                    ))
                }
                
                // Move to next book (after all blocks)
                i = blocks.endIndex
                
                // If we didn't make progress, advance by one to avoid infinite loop
                if i == blocks.startIndex {
                    i += 1
                }
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
    
    /// Block structure for organizing text lines
    private struct TextBlocks {
        let title: [String]
        let author: [String]
        let publisher: [String]
        let startIndex: Int
        let endIndex: Int
    }
    
    /// Isolate text into distinct blocks: title, author, publisher
    private func isolateBlocks(from lines: [String], startingAt startIndex: Int) -> TextBlocks {
        guard startIndex < lines.count else {
            return TextBlocks(title: [], author: [], publisher: [], startIndex: startIndex, endIndex: startIndex)
        }
        
        var titleLines: [String] = []
        var authorLines: [String] = []
        var publisherLines: [String] = []
        
        var i = startIndex
        var currentBlock: BlockType = .title
        
        enum BlockType {
            case title
            case author
            case publisher
        }
        
        var lastIndex = i
        var iterations = 0
        let maxIterations = lines.count - startIndex + 10 // Safety limit
        
        while i < lines.count && iterations < maxIterations {
            iterations += 1
            let line = lines[i]
            
            // Check if this is a new book (large title-like text)
            if currentBlock == .title && titleLines.isEmpty {
                // First line is always title
                titleLines.append(line)
                i += 1
                lastIndex = i
                continue
            }
            
            // Determine block transitions
            switch currentBlock {
            case .title:
                // Continue collecting title lines
                if isTitleContinuation(line, previousTitleLines: titleLines) {
                    titleLines.append(line)
                    i += 1
                    lastIndex = i
                } else if isAuthorLine(line) {
                    // Transition to author block
                    currentBlock = .author
                    authorLines.append(line)
                    i += 1
                    lastIndex = i
                } else if isPublisherName(line) {
                    // Transition to publisher block
                    currentBlock = .publisher
                    publisherLines.append(line)
                    i += 1
                    lastIndex = i
                } else if isLikelyTitle(line) && line.count > (titleLines.joined().count) {
                    // New book - stop here
                    break
                } else {
                    // Ambiguous - try to determine
                    if isLikelyAuthorName(line) {
                        currentBlock = .author
                        authorLines.append(line)
                    } else if isPublisherName(line) {
                        currentBlock = .publisher
                        publisherLines.append(line)
                    } else {
                        // Assume title continuation if uncertain
                        titleLines.append(line)
                    }
                    i += 1
                    lastIndex = i
                }
                
            case .author:
                // Continue collecting author lines
                if isAuthorContinuation(line, previousAuthorLines: authorLines) {
                    authorLines.append(line)
                    i += 1
                    lastIndex = i
                } else if isPublisherName(line) {
                    // Transition to publisher block
                    currentBlock = .publisher
                    publisherLines.append(line)
                    i += 1
                    lastIndex = i
                } else if isLikelyTitle(line) && line.count > (titleLines.joined().count) {
                    // New book - stop here
                    break
                } else {
                    // Doesn't look like author continuation - might be publisher or new book
                    if isPublisherName(line) {
                        currentBlock = .publisher
                        publisherLines.append(line)
                        i += 1
                        lastIndex = i
                    } else {
                        // End of author block
                        break
                    }
                }
                
            case .publisher:
                // Continue collecting publisher lines (multi-line publishers)
                if isPublisherContinuation(line, previousPublisherLines: publisherLines) {
                    publisherLines.append(line)
                    i += 1
                    lastIndex = i
                } else {
                    // End of publisher block - likely new book
                    break
                }
            }
            
            // Safety check: if we haven't advanced, force advance
            if i == lastIndex && iterations > 1 {
                i += 1
                lastIndex = i
            }
        }
        
        // Ensure we always advance at least one position
        let finalIndex = max(lastIndex, startIndex + 1)
        
        return TextBlocks(
            title: titleLines,
            author: authorLines,
            publisher: publisherLines,
            startIndex: startIndex,
            endIndex: finalIndex
        )
    }
    
    /// Process title block - combine multi-line titles and normalize case
    private func processTitleBlock(_ titleLines: [String]) -> String {
        guard !titleLines.isEmpty else { return "" }
        let combined = combineTitleLines(titleLines)
        return normalizeCase(combined)
    }
    
    /// Process author block - combine multi-line authors and normalize case
    private func processAuthorBlock(_ authorLines: [String]) -> String? {
        guard !authorLines.isEmpty else { return nil }
        let combined = combineAuthors(authorLines)
        return combined.isEmpty ? nil : normalizeCase(combined)
    }
    
    /// Process publisher block - combine multi-line publishers and normalize case
    private func processPublisherBlock(_ publisherLines: [String]) -> String? {
        guard !publisherLines.isEmpty else { return nil }
        let combined = publisherLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return combined.isEmpty ? nil : normalizeCase(combined)
    }
    
    /// Normalize text case: convert all caps to proper case
    private func normalizeCase(_ text: String) -> String {
        // If text is all caps (or mostly caps), convert to proper case
        let uppercaseCount = text.filter { $0.isUppercase && $0.isLetter }.count
        let letterCount = text.filter { $0.isLetter }.count
        
        guard letterCount > 0 else { return text }
        
        let uppercaseRatio = Double(uppercaseCount) / Double(letterCount)
        
        // If more than 80% uppercase, convert to proper case
        if uppercaseRatio > 0.8 {
            return text.capitalized
        }
        
        // Otherwise preserve original case
        return text
    }
    
    /// Check if a line is a continuation of the author block
    private func isAuthorContinuation(_ line: String, previousAuthorLines: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // If it's clearly a publisher, it's not an author continuation
        if isPublisherName(trimmed) {
            return false
        }
        
        // If it looks like a new title, it's not an author continuation
        if isLikelyTitle(trimmed) && trimmed.count > 20 {
            return false
        }
        
        // Author continuations often:
        // 1. Contain author indicators (AND, &, comma)
        if containsAuthorIndicators(trimmed) {
            return true
        }
        
        // 2. Look like author names (2-4 words, proper capitalization)
        if isLikelyAuthorName(trimmed) {
            return true
        }
        
        // 3. Are short lines that could be part of a name
        if trimmed.count < 30 && trimmed.first?.isUppercase == true {
            return true
        }
        
        return false
    }
    
    /// Check if a line is a continuation of the publisher block
    private func isPublisherContinuation(_ line: String, previousPublisherLines: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        
        // Publisher continuations often:
        // 1. Contain publisher keywords
        if isPublisherName(trimmed) {
            return true
        }
        
        // 2. Are short, uppercase lines (like "INC", "LLC")
        if trimmed.count < 10 && trimmed == trimmed.uppercased() {
            return true
        }
        
        // 3. Are part of a longer publisher name
        if trimmed.count < 30 && !trimmed.contains(",") {
            return true
        }
        
        return false
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
    /// Determine if a line is a continuation of the title
    private func isTitleContinuation(_ line: String, previousTitleLines: [String]) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Empty or too short - not a title continuation
        guard trimmed.count > 1 else { return false }
        
        // PRIORITY CHECKS: If it looks like an author, it's NOT a title continuation
        // Check this FIRST before checking title continuation patterns
        
        // If it looks like an author name (starts with capital, has common name patterns), it's not a title continuation
        if isLikelyAuthorName(trimmed) {
            return false
        }
        
        // If it contains author indicators, it's not a title continuation
        if containsAuthorIndicators(trimmed) {
            return false
        }
        
        // If it's clearly a publisher, it's not a title continuation
        if isPublisherName(trimmed) {
            return false
        }
        
        // Additional check: if it looks like a person's name (2-4 words, proper capitalization, no title words)
        let wordCount = trimmed.components(separatedBy: .whitespaces).count
        if wordCount >= 2 && wordCount <= 4 {
            let lowercased = trimmed.lowercased()
            let titleWords = ["of", "the", "a", "an", "in", "on", "at", "for", "with", "from", "to"]
            let words = lowercased.components(separatedBy: .whitespaces)
            let hasTitleWords = words.contains { titleWords.contains($0) }
            
            // If it doesn't have title words and all words start with capital, it's likely a name
            if !hasTitleWords && trimmed.first?.isUppercase == true {
                let capitalizedWords = words.filter { word in
                    word.count > 0 && word.first?.isUppercase == true
                }
                // If most words are capitalized, it's likely a name, not a title continuation
                if capitalizedWords.count >= wordCount - 1 {
                    return false
                }
            }
        }
        
        // Title continuations are often:
        // 1. All caps or mostly caps (like "WORLD LITERATURE")
        let uppercaseCount = trimmed.filter { $0.isUppercase && $0.isLetter }.count
        let letterCount = trimmed.filter { $0.isLetter }.count
        if letterCount > 0 {
            let uppercaseRatio = Double(uppercaseCount) / Double(letterCount)
            if uppercaseRatio > 0.7 {
                return true
            }
        }
        
        // 2. Short lines that don't contain author patterns
        if trimmed.count < 30 && !trimmed.contains(",") && !trimmed.lowercased().contains(" by ") {
            return true
        }
        
        // 3. Lines that start with common title words
        let titleStarters = ["the", "a", "an", "of", "in", "on", "at", "for", "with", "from", "to"]
        let firstWord = trimmed.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
        if titleStarters.contains(firstWord) {
            return true
        }
        
        // 4. If previous title line ends with "of", "the", etc., next line is likely continuation
        if let lastTitle = previousTitleLines.last?.lowercased() {
            if lastTitle.hasSuffix(" of") || lastTitle.hasSuffix(" the") || lastTitle.hasSuffix(" a") || lastTitle.hasSuffix(" an") {
                return true
            }
        }
        
        return false
    }
    
    /// Determine if a line is likely an author name
    private func isLikelyAuthorName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Author names often:
        // 1. Start with capital letter
        guard let firstChar = trimmed.first, firstChar.isUppercase else { return false }
        
        // 2. Contain comma (last, first format)
        if trimmed.contains(",") {
            return true
        }
        
        // 3. Are 2-4 words (typical name length, including middle names)
        let wordCount = trimmed.components(separatedBy: .whitespaces).count
        if wordCount >= 2 && wordCount <= 4 {
            // Check if it contains common name patterns
            let lowercased = trimmed.lowercased()
            if lowercased.contains(" and ") || lowercased.contains(" & ") {
                return true
            }
            
            // Check for common name patterns (first name, middle name, last name)
            // Names typically don't contain common title words
            let titleWords = ["of", "the", "a", "an", "in", "on", "at", "for", "with", "from", "to"]
            let words = trimmed.lowercased().components(separatedBy: .whitespaces)
            let hasTitleWords = words.contains { titleWords.contains($0) }
            
            // If it's a reasonable length, doesn't contain title words, and looks like a name
            if trimmed.count < 50 && !hasTitleWords {
                // Additional check: names often have proper capitalization (first letter of each word)
                let capitalizedWords = words.filter { word in
                    word.count > 0 && word.first?.isUppercase == true
                }
                // If most words start with capital, it's likely a name
                if capitalizedWords.count >= wordCount - 1 {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Determine if a line is an author line
    private func isAuthorLine(_ line: String) -> Bool {
        return isLikelyAuthorName(line) || containsAuthorIndicators(line)
    }
    
    /// Combine multiple title lines into a single title string
    private func combineTitleLines(_ titleLines: [String]) -> String {
        guard !titleLines.isEmpty else { return "" }
        
        // If single line, return as-is
        if titleLines.count == 1 {
            return titleLines[0].trimmingCharacters(in: .whitespaces)
        }
        
        // Multiple lines - combine with space, preserving original formatting
        return titleLines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
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
