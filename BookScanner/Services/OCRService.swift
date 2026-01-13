import UIKit
import Vision

class OCRService: ObservableObject {
    func recognizeBooks(from image: UIImage, completion: @escaping ([Book]) -> Void) {
        guard let cgImage = image.cgImage else {
            completion([])
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion([])
                return
            }
            
            var recognizedBooks: [Book] = []
            var currentText = ""
            
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else {
                    continue
                }
                currentText += topCandidate.string + "\n"
            }
            
            // Parse text to extract book information
            let lines = currentText.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            // Simple parsing logic - can be enhanced with ML models
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.count > 3 {
                    // Try to identify title and author patterns
                    let components = trimmed.components(separatedBy: CharacterSet(charactersIn: "|,;"))
                    
                    if components.count >= 2 {
                        let title = components[0].trimmingCharacters(in: .whitespaces)
                        let author = components[1].trimmingCharacters(in: .whitespaces)
                        
                        if !title.isEmpty && !author.isEmpty {
                            let book = Book(
                                title: title,
                                author: author,
                                imageData: image.jpegData(compressionQuality: 0.8)
                            )
                            recognizedBooks.append(book)
                        }
                    } else if !trimmed.isEmpty {
                        // Single line - assume it's a title, author unknown
                        let book = Book(
                            title: trimmed,
                            author: "Unknown",
                            imageData: image.jpegData(compressionQuality: 0.8)
                        )
                        recognizedBooks.append(book)
                    }
                }
            }
            
            // If no structured data found, create a single book entry with all text
            if recognizedBooks.isEmpty && !currentText.trimmingCharacters(in: .whitespaces).isEmpty {
                let book = Book(
                    title: currentText.components(separatedBy: .newlines).first ?? "Unknown Title",
                    author: "Unknown",
                    imageData: image.jpegData(compressionQuality: 0.8)
                )
                recognizedBooks.append(book)
            }
            
            completion(recognizedBooks)
        }
        
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("OCR error: \(error.localizedDescription)")
            completion([])
        }
    }
}
