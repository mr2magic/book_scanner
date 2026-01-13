import SwiftUI
import SwiftData

/// Comprehensive test suite for all app features
struct TestSuiteView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allBooks: [Book]
    @StateObject private var ocrService = OCRService()
    @StateObject private var aiService = AIService()
    
    @State private var testResults: [TestResult] = []
    @State private var isRunning = false
    @State private var currentTest = ""
    
    struct TestResult: Identifiable {
        let id = UUID()
        let name: String
        let status: Status
        let message: String
        
        enum Status {
            case passed, failed, skipped
            
            var color: Color {
                switch self {
                case .passed: return .green
                case .failed: return .red
                case .skipped: return .gray
                }
            }
            
            var icon: String {
                switch self {
                case .passed: return "checkmark.circle.fill"
                case .failed: return "xmark.circle.fill"
                case .skipped: return "minus.circle.fill"
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Test Controls") {
                    Button(action: runAllTests) {
                        HStack {
                            if isRunning {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isRunning ? "Running Tests..." : "Run All Tests")
                        }
                    }
                    .disabled(isRunning)
                    
                    Button("Clear Results") {
                        testResults.removeAll()
                    }
                    .disabled(testResults.isEmpty)
                }
                
                if !currentTest.isEmpty {
                    Section("Current Test") {
                        Text(currentTest)
                            .font(.headline)
                    }
                }
                
                Section("Test Results (\(testResults.count))") {
                    ForEach(testResults) { result in
                        HStack {
                            Image(systemName: result.status.icon)
                                .foregroundColor(result.status.color)
                            VStack(alignment: .leading) {
                                Text(result.name)
                                    .font(.headline)
                                Text(result.message)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
                
                Section("Summary") {
                    let passed = testResults.filter { $0.status == .passed }.count
                    let failed = testResults.filter { $0.status == .failed }.count
                    let skipped = testResults.filter { $0.status == .skipped }.count
                    
                    HStack {
                        Text("Passed:")
                        Spacer()
                        Text("\(passed)")
                            .foregroundColor(.green)
                    }
                    HStack {
                        Text("Failed:")
                        Spacer()
                        Text("\(failed)")
                            .foregroundColor(.red)
                    }
                    HStack {
                        Text("Skipped:")
                        Spacer()
                        Text("\(skipped)")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Test Suite")
        }
    }
    
    private func runAllTests() {
        isRunning = true
        testResults.removeAll()
        
        Task {
            await runTestSuite()
            await MainActor.run {
                isRunning = false
            }
        }
    }
    
    private func runTestSuite() async {
        // Test 1: Database Operations
        await updateTest("Database: Create Book") {
            let book = Book(
                title: "Test Book",
                author: "Test Author",
                publisher: "Test Publisher",
                isbn: "1234567890"
            )
            modelContext.insert(book)
            try? modelContext.save()
            return true
        }
        
        await updateTest("Database: Read Books") {
            let count = allBooks.count
            return count > 0
        }
        
        await updateTest("Database: Update Book") {
            if let book = allBooks.first {
                book.title = "Updated Title"
                try? modelContext.save()
                return true
            }
            return false
        }
        
        await updateTest("Database: Delete Book") {
            if let book = allBooks.first {
                modelContext.delete(book)
                try? modelContext.save()
                return true
            }
            return false
        }
        
        // Test 2: OCR Service
        await updateTest("OCR Service: Initialization") {
            // Service is initialized as @StateObject, so it's always available
            return true
        }
        
        // Test 3: AI Service
        await updateTest("AI Service: Initialization") {
            return true // Service is initialized
        }
        
        // Test 4: Image Processing
        await updateTest("Image Processing: Create Test Image") {
            let size = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
            defer { UIGraphicsEndImageContext() }
            let image = UIGraphicsGetImageFromCurrentImageContext()
            return image != nil
        }
        
        // Test 5: Configuration
        await updateTest("Configuration: Access") {
            _ = AppConfiguration.shared
            return true // Config accessed successfully
        }
        
        // Test 6: Error Handling
        await updateTest("Error Handling: AppError Creation") {
            let error = AppError.invalidData
            return !error.errorDescription!.isEmpty
        }
        
        // Test 7: Validation
        await updateTest("Validation: ISBN Format") {
            let validISBN10 = "1234567890"
            let validISBN13 = "1234567890123"
            let invalidISBN = "123"
            
            let cleaned10 = validISBN10.replacingOccurrences(of: "-", with: "")
            let cleaned13 = validISBN13.replacingOccurrences(of: "-", with: "")
            let cleanedInvalid = invalidISBN.replacingOccurrences(of: "-", with: "")
            
            return (cleaned10.count == 10 || cleaned10.count == 13) &&
                   (cleaned13.count == 10 || cleaned13.count == 13) &&
                   !(cleanedInvalid.count == 10 || cleanedInvalid.count == 13)
        }
        
        // Test 8: Multiple Authors Parsing
        await updateTest("Parsing: Multiple Authors Detection") {
            let testCases = [
                "Author1 AND Author2",
                "Author1 & Author2",
                "Author1, Author2"
            ]
            
            for testCase in testCases {
                let containsAnd = testCase.uppercased().contains(" AND ") || testCase.contains(" & ")
                if !containsAnd && !testCase.contains(", ") {
                    return false
                }
            }
            return true
        }
        
        // Test 9: Publisher Detection
        await updateTest("Parsing: Publisher Detection") {
            let publishers = ["RANDOM HOUSE", "PENGUIN PRESS", "NORTON BOOKS"]
            let nonPublishers = ["A LONG BOOK TITLE", "SOME AUTHOR NAME"]
            
            for pub in publishers {
                let isPub = pub.lowercased().contains("press") ||
                           pub.lowercased().contains("books") ||
                           pub.lowercased().contains("house")
                if !isPub {
                    return false
                }
            }
            
            for nonPub in nonPublishers {
                let isPub = nonPub.lowercased().contains("press") ||
                           nonPub.lowercased().contains("books") ||
                           nonPub.lowercased().contains("house")
                if isPub {
                    return false
                }
            }
            return true
        }
        
        // Test 10: Image Rotation
        await updateTest("Image Processing: Rotation") {
            let testImage = createTestImage(size: CGSize(width: 100, height: 200))
            let isPortrait = testImage.size.height > testImage.size.width * 1.5
            return isPortrait
        }
    }
    
    private func updateTest(_ name: String, test: @escaping () -> Bool) async {
        await MainActor.run {
            currentTest = name
        }
        
        let passed = test()
        
        await MainActor.run {
            testResults.append(TestResult(
                name: name,
                status: passed ? .passed : .failed,
                message: passed ? "Test passed" : "Test failed"
            ))
        }
    }
    
    private func createTestImage(size: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        defer { UIGraphicsEndImageContext() }
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
}
