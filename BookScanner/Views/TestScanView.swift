import SwiftUI
import UIKit

struct TestScanView: View {
    @StateObject private var ocrService = OCRService()
    @StateObject private var aiService = AIService()
    @State private var ocrResults: [Book] = []
    @State private var aiResults: [Book] = []
    @State private var isProcessing = false
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var ocrComplete = false
    @State private var aiComplete = false
    
    // Expected books from the image description (31 books)
    let expectedBooks = [
        ("A TRIAL OF GENERALS", "TAYLOR", "ICARUS"),
        ("THE FORGER", "CIOMA SCHÖNHAUS", "Granta"),
        ("THE SECOND WORLD WAR IN THE WEST", "MESSENGER C", ""),
        ("CLASSICAL AND CONTEMPORARY READINGS IN THE PHILOSOPHY OF RELIGION", "HICK", "PRENTICE HALL"),
        ("HIS TRUTH IS MARCHING ON", "JON MEACHAM", "RANDOM HOUSE"),
        ("families as they really are", "EDITED BY BARBARA J. RISHMAN", "NORTON"),
        ("Going Solo The Extraordinary Rise and Surprising Appeal of Living Alone", "Eric Klinenberg", "PENGUIN"),
        ("JUST FOOD WHERE LOCAVORES GET IT WRONG AND HOW WE CAN TRULY EAT RESPONSIBLY", "JAMES E. MCWILLIAMS", ""),
        ("SOCIAL STRATIFICATION AND INEQUALITY CLASS CONFLICT IN HISTORICAL, COMPARATIVE, AND GLOBAL PERSPECTIVE", "Kerbo", ""),
        ("DEATH AT THE PARASITE CAFE & THE POSTMODERN", "PFOHL", "ST. MARTIN'S PRESS"),
        ("the Butterfly Effect", "Marcus J. Morre", "ATRIUM"),
        ("Why Are All the Black Kids Sitting Together in the Cafeteria?", "BEVERLY DANIEL TATUM, PH.D.", "BASIC BOOKS"),
        ("RAISING ANTIRACIST CHILDREN", "BRITT HAWTHORNE", ""),
        ("We Are Our Mothers' Daughters REVISED AND EXPANDED EDITION", "Cokie Roberts", "HARPER PERENNIAL"),
        ("STRONG WOMEN SOFT HEARTS", "Paula Rinehart", ""),
        ("THE ARMCHAIR ECONOMIST", "Landsburg", "FREE PRESS"),
        ("In Search of Sisterhood", "GIDDINGS", "MORROW"),
        ("THE FEAR The Last Days of ROBERT MUGABE", "PETER GODWIN", "PICADOR"),
        ("Europe's Classical Balance of Power", "Gulick", ""),
        ("FAMOUS GUNFIGHTERS OF THE WESTERN FRONTIER", "MASTERSON", "DOVER"),
        ("A MAN OF TWO FACES", "VIET THANH NGUYEN", ""),
        ("Digital Photography FOR DUMMIES 3rd Edition", "King", ""),
        ("BIG MONEY CRIME", "CALAVITA PONTELL TILLMAN", "California"),
        ("MAVERICK A BIOGRAPHY OF THOMAS SOWELL", "JASON L. RILEY", "BASIC BOOKS"),
        ("A SPY'S JOURNEY", "PASEMAN", "ZENITH PRESS"),
        ("THE Liberal Mind The Psychological Causes of POLITICAL MADNESS", "ROSSITER", "Free World Books, LLC"),
        ("A STAKE IN THE OUTCOME", "JACK STACK AND BO BURLINGHAM", ""),
        ("THE BOOK OF GUTSY WOMEN", "Hillary Rodham Clinton AND Chelsea Clinton", ""),
        ("UNDER THE SKIN", "LINDA VILLAROSA", ""),
        ("THE NORTON ANTHOLOGY OF WORLD LITERATURE SHORTER THIRD EDITION VOLUME 2 1650 TO THE PRESENT", "", "NORTON"),
        ("THE WORLD IS FLAT", "THOMAS L. FRIEDMAN", "PICADOR")
    ]
    
    @State private var processingLog: [String] = []
    @State private var rectanglesDetected = 0
    @State private var booksGrouped = 0
    
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
                    if !ocrResults.isEmpty {
                        Section("OCR Results (\(ocrResults.count))") {
                            ForEach(ocrResults) { book in
                                BookResultRow(book: book, method: "OCR")
                            }
                        }
                        .padding()
                    }
                    
                    // AI Results
                    if !aiResults.isEmpty {
                        Section("AI Results (\(aiResults.count))") {
                            ForEach(aiResults) { book in
                                BookResultRow(book: book, method: "AI")
                            }
                        }
                        .padding()
                    }
                    
                    // Processing Log
                    if !processingLog.isEmpty {
                        Section("Processing Log") {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(processingLog, id: \.self) { logEntry in
                                        Text(logEntry)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding()
                    }
                    
                    // Comparison
                    Section("Comparison") {
                        Text("Expected: \(expectedBooks.count) books")
                        Text("OCR Found: \(ocrResults.count) books")
                        Text("AI Found: \(aiResults.count) books")
                        
                        if rectanglesDetected > 0 {
                            Text("Rectangles Detected: \(rectanglesDetected)")
                            Text("Books Grouped: \(booksGrouped)")
                        }
                        
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
        processingLog = []
        rectanglesDetected = 0
        booksGrouped = 0
        
        addLog("Starting processing...")
        addLog("Image size: \(Int(image.size.width))x\(Int(image.size.height))")
        
        // Process with OCR
        Task {
            do {
                addLog("OCR: Starting recognition...")
                let books = try await ocrService.recognizeBooks(from: image)
                await MainActor.run {
                    self.ocrResults = books
                    self.ocrComplete = true
                    self.addLog("OCR: Found \(books.count) books")
                    if self.ocrComplete && self.aiComplete {
                        self.isProcessing = false
                        self.addLog("Processing complete!")
                    }
                }
            } catch {
                await MainActor.run {
                    self.addLog("OCR Error: \(error.localizedDescription)")
                    self.ocrComplete = true
                    if self.ocrComplete && self.aiComplete {
                        self.isProcessing = false
                    }
                }
            }
        }
        
        // Process with AI
        Task {
            do {
                addLog("AI: Starting recognition...")
                let books = try await aiService.recognizeBooks(from: image)
                await MainActor.run {
                    self.aiResults = books
                    self.aiComplete = true
                    self.addLog("AI: Found \(books.count) books")
                    if self.ocrComplete && self.aiComplete {
                        self.isProcessing = false
                        self.addLog("Processing complete!")
                    }
                }
            } catch {
                await MainActor.run {
                    self.addLog("AI Error: \(error.localizedDescription)")
                    self.aiComplete = true
                    if self.ocrComplete && self.aiComplete {
                        self.isProcessing = false
                    }
                }
            }
        }
        
        // Monitor progress
        Task {
            while isProcessing {
                await MainActor.run {
                    if let progress = ocrService.scanProgress {
                        self.addLog("OCR: \(progress.stage) - \(progress.current)/\(progress.total)")
                    }
                    if let progress = aiService.scanProgress {
                        self.addLog("AI: \(progress.stage) - \(progress.current)/\(progress.total)")
                    }
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        processingLog.append("[\(timestamp)] \(message)")
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
