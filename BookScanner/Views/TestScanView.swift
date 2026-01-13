import SwiftUI
import UIKit

struct TestScanView: View {
    private let ocrService = OCRService()
    private let aiService = AIService()
    @State private var ocrResults: [Book] = []
    @State private var aiResults: [Book] = []
    @State private var isProcessing = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var ocrComplete = false
    @State private var aiComplete = false
    
    // Expected books from the image description
    let expectedBooks = [
        ("TAYLOR A TRIAL OF GENERALS", "ICARUS"),
        ("THE FORGER CIOMA SCHÖNHAUS", "Granta"),
        ("THE SECOND WORLD WAR IN THE WEST", "MESSENGER C"),
        ("CLASSICAL AND CONTEMPORARY READINGS IN THE PHILOSOPHY OF RELIGION", "HICK"),
        ("HIS TRUTH IS MARCHING ON", "JON MEACHAM"),
        ("families as they really are", "BARBARA J. RISHMAN"),
        ("Going Solo The Extraordinary Rise and Surprising Appeal of Living Alone", "Eric Klinenberg"),
        ("JUST FOOD", "JAMES E RCWILLIAMS"),
        ("SOCIAL STRATIFICATION AND INEQUALITY", "Kerbo"),
        ("DEATH AT THE PARASITE CAFE", "PFOHL"),
        ("the Butterfly Effect", "Marcus J. More"),
        ("RAISING ANTIRACIST CHILDREN", "BRITT HAWTHORNE"),
        ("We Are Our Mothers Daughters", "Cokie Roberts"),
        ("STRONG WOMEN SOFT HEARTS", "Paula Rinehart"),
        ("ARMCHAIR ECONOMIST", "Landsburg"),
        ("In Search of Sisterhood", "GIDDINGS"),
        ("THE FEAR THE LAST DAYS OF ROBERT MUGABE", "PETER GODWIN"),
        ("Europe's Classical Balance of Power", "Gulick"),
        ("FAMOUS GUNFIGHTERS OF THE WESTERN FRONTIER", "MASTERSON"),
        ("A MAN OF TWO FACES", "VIET THANH NGUYEN"),
        ("Digital Photography DUMMIES", "King"),
        ("BIG MONEY CRIME", "CALAVITA PONTELL TILLMAN"),
        ("MAVERICK A BIOGRAPHY OF THOMAS SOWELL", "JASON L. RILEY"),
        ("A SPY'S JOURNEY", "PASEMAN"),
        ("THE Liberal Mind The Psychological Causes of POLITICAL MADNESS", "ROSSITER"),
        ("A STAKE IN THE OUTCOME", "JACK STACK AND BO BURLINGHAM"),
        ("THE BOOK OF GUTSY WOMEN", "Hillary Rodham Clinton AND Chelsea Clinton"),
        ("UNDER THE SKIN", "LINDA VILLAROSA"),
        ("THE NORTON ANTHOLOGY OF WORLD LITERATURE", "NORTON"),
        ("THE WORLD IS FLAT A BRIEF HISTORY OF THE TWENTY-FIRST CENTURY", "THOMAS L FRIEDMAN")
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Image selection
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(12)
                            .padding()
                    }
                    
                    Button("Select Test Image") {
                        showImagePicker = true
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                    
                    if isProcessing {
                        ProgressView("Processing...")
                            .padding()
                    }
                    
                    // OCR Results
                    Section("OCR Results (\(ocrResults.count))") {
                        ForEach(ocrResults) { book in
                            BookResultRow(book: book, method: "OCR")
                        }
                    }
                    .padding()
                    
                    // AI Results
                    Section("AI Results (\(aiResults.count))") {
                        ForEach(aiResults) { book in
                            BookResultRow(book: book, method: "AI")
                        }
                    }
                    .padding()
                    
                    // Comparison
                    Section("Comparison") {
                        Text("Expected: \(expectedBooks.count) books")
                        Text("OCR Found: \(ocrResults.count) books")
                        Text("AI Found: \(aiResults.count) books")
                        
                        let ocrAccuracy = Double(ocrResults.count) / Double(expectedBooks.count) * 100
                        let aiAccuracy = Double(aiResults.count) / Double(expectedBooks.count) * 100
                        
                        Text("OCR Accuracy: \(String(format: "%.1f", ocrAccuracy))%")
                        Text("AI Accuracy: \(String(format: "%.1f", aiAccuracy))%")
                    }
                    .padding()
                }
            }
            .navigationTitle("Test Scan")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary) { image in
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        ocrResults = []
        aiResults = []
        ocrComplete = false
        aiComplete = false
        
        // Process with OCR
        ocrService.recognizeBooks(from: image) { books in
            DispatchQueue.main.async {
                self.ocrResults = books
                self.ocrComplete = true
                if self.ocrComplete && self.aiComplete {
                    self.isProcessing = false
                }
            }
        }
        
        // Process with AI
        aiService.recognizeBooks(from: image) { books in
            DispatchQueue.main.async {
                self.aiResults = books
                self.aiComplete = true
                if self.ocrComplete && self.aiComplete {
                    self.isProcessing = false
                }
            }
        }
    }
}

struct BookResultRow: View {
    let book: Book
    let method: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(method)
                    .font(.caption)
                    .padding(4)
                    .background(method == "OCR" ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                    .cornerRadius(4)
                Spacer()
            }
            Text("Title: \(book.title)")
                .font(.headline)
            Text("Author: \(book.author)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if let publisher = book.publisher {
                Text("Publisher: \(publisher)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
