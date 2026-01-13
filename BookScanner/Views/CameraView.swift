import SwiftUI
import AVFoundation
import PhotosUI
import UIKit

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ocrService = OCRService()
    @StateObject private var aiService = AIService()
    @StateObject private var settings = AppSettings()
    @State private var showImagePicker = false
    @State private var showPhotoLibraryPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var showProcessing = false
    @State private var showResult = false
    @State private var showComparison = false
    @State private var recognizedBooks: [Book] = []
    @State private var ocrBooks: [Book] = []
    @State private var aiBooks: [Book] = []
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    @State private var showCompletionAlert = false
    @State private var completionMessage = ""
    @State private var isProcessing = false
    @State private var failedBooks: [Int] = []
    @State private var showFailedBooksAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .padding()
                }
                
                // Scan method selection
                Picker("Scan Method", selection: $settings.scanMethod) {
                    ForEach(AppSettings.ScanMethod.allCases, id: \.self) { method in
                        Text(method.rawValue).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 40)
                .onChange(of: settings.scanMethod) { _, _ in
                    settings.saveSettings()
                }
                
                VStack(spacing: 12) {
                    Button(action: {
                        guard !isProcessing else { return }
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                        }
                        .font(.headline)
                        .foregroundColor(isProcessing ? .gray : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray.opacity(0.5) : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    .accessibilityLabel("Take photo of book spines")
                    
                    Button(action: {
                        guard !isProcessing else { return }
                        showPhotoLibraryPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                        }
                        .font(.headline)
                        .foregroundColor(isProcessing ? .gray : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray.opacity(0.5) : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    .accessibilityLabel("Choose image from photo library")
                }
                .padding(.horizontal, 40)
                
                if showProcessing {
                    VStack(spacing: 12) {
                        // Show progress from active service
                        if let progress = ocrService.scanProgress {
                            VStack(spacing: 8) {
                                ProgressView(value: progress.progress) {
                                    HStack {
                                        Text(progress.stage)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(progress.current) of \(progress.total)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .progressViewStyle(.linear)
                                Text("\(progress.current) of \(progress.total) books processed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else if let progress = aiService.scanProgress {
                            VStack(spacing: 8) {
                                ProgressView(value: progress.progress) {
                                    HStack {
                                        Text(progress.stage)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Spacer()
                                        Text("\(progress.current) of \(progress.total)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .progressViewStyle(.linear)
                                Text("\(progress.current) of \(progress.total) books processed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else {
                            ProgressView("Processing image...")
                        }
                    }
                    .padding()
                }
                
                // Version number
                Text("Version 1.1")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
            .navigationTitle("Scan Books")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera, onImageSelected: { image in
                    processImage(image)
                })
                .onDisappear {
                    // Reset picker state when dismissed
                    showImagePicker = false
                }
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary, onImageSelected: { image in
                    processImage(image)
                })
                .onDisappear {
                    // Reset picker state when dismissed
                    showPhotoLibraryPicker = false
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    guard let newItem = newItem else { return }
                    
                    do {
                        if let data = try await newItem.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            await MainActor.run {
                                selectedImage = image
                                processImage(image)
                            }
                        } else {
                            print("Failed to load image data")
                        }
                    } catch {
                        print("Error loading image: \(error.localizedDescription)")
                    }
                }
            }
            .sheet(isPresented: $showResult) {
                if settings.compareResults && !ocrBooks.isEmpty && !aiBooks.isEmpty {
                    ComparisonView(ocrBooks: ocrBooks, aiBooks: aiBooks) { books in
                        updateBooks(books)
                    }
                } else {
                    BookRecognitionResultView(books: recognizedBooks) { books in
                        updateBooks(books)
                    }
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .alert("Completed", isPresented: $showCompletionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(completionMessage)
            }
            .alert("Some Books Failed to Scan", isPresented: $showFailedBooksAlert) {
                Button("OK", role: .cancel) { }
                Button("Retry", role: .none) {
                    // User can retry by taking a new photo
                }
            } message: {
                if !failedBooks.isEmpty {
                    Text("Books \(failedBooks.map { String($0) }.joined(separator: ", ")) could not be scanned. Please take a new photo with better lighting.")
                } else {
                    Text("Some books could not be scanned. Please take a new photo with better lighting.")
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        // Prevent multiple simultaneous processing
        guard !isProcessing else {
            return
        }
        
        // Process in background but update UI on main thread
        Task {
            await MainActor.run {
                isProcessing = true
                showProcessing = true
                recognizedBooks = []
                ocrBooks = []
                aiBooks = []
            }
            
            do {
                let books: [Book]
                
                switch settings.scanMethod {
                case .ocr:
                    // Process in background
                    books = try await ocrService.recognizeBooks(from: image, useFullImageScan: settings.useFullImageScan)
                    
                    await MainActor.run {
                        showProcessing = false
                        isProcessing = false
                        recognizedBooks = books
                        ocrBooks = books
                        
                        if books.isEmpty {
                            showError("No books detected in image. Try enabling 'Use Full Image Scan' in Settings to test full image processing.")
                        } else {
                            // Auto-save books immediately
                            saveBooks(books)
                            completionMessage = "Found and saved \(books.count) book\(books.count == 1 ? "" : "s") using OCR"
                            showCompletionAlert = true
                            showResult = true
                        }
                    }
                    
                case .ai:
                    // Process in background
                    books = try await aiService.recognizeBooks(from: image, useFullImageScan: settings.useFullImageScan)
                    
                    await MainActor.run {
                        showProcessing = false
                        isProcessing = false
                        recognizedBooks = books
                        aiBooks = books
                        
                        if books.isEmpty {
                            showError("No books detected in image. Try enabling 'Use Full Image Scan' in Settings to test full image processing.")
                        } else {
                            // Auto-save books immediately
                            saveBooks(books)
                            completionMessage = "Found and saved \(books.count) book\(books.count == 1 ? "" : "s") using AI"
                            showCompletionAlert = true
                            showResult = true
                        }
                    }
                    
                case .both:
                    // Process both in parallel in background
                    async let ocrTask = ocrService.recognizeBooks(from: image, useFullImageScan: settings.useFullImageScan)
                    async let aiTask = aiService.recognizeBooks(from: image, useFullImageScan: settings.useFullImageScan)
                    
                    let (ocrResult, aiResult) = try await (ocrTask, aiTask)
                    
                    await MainActor.run {
                        showProcessing = false
                        isProcessing = false
                        ocrBooks = ocrResult
                        aiBooks = aiResult
                        
                        let totalBooks = settings.compareResults ? max(ocrResult.count, aiResult.count) : (ocrResult.count + aiResult.count)
                        
                        if totalBooks == 0 {
                            showError("No books detected in image")
                        } else {
                            if settings.compareResults {
                                // When comparing, don't auto-save - let user choose from comparison view
                                completionMessage = "OCR found \(ocrResult.count) book\(ocrResult.count == 1 ? "" : "s"), AI found \(aiResult.count) book\(aiResult.count == 1 ? "" : "s")"
                            } else {
                                // Auto-save all books from both methods
                                let allBooks = ocrResult + aiResult
                                saveBooks(allBooks)
                                recognizedBooks = allBooks
                                completionMessage = "Found and saved \(totalBooks) book\(totalBooks == 1 ? "" : "s") using OCR and AI"
                            }
                            showCompletionAlert = true
                            showResult = true
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    showProcessing = false
                    isProcessing = false
                    showError(error.localizedDescription)
                }
            }
        }
    }
    
    private func showError(_ message: String) {
        Task { @MainActor in
            self.errorMessage = message
            self.showErrorAlert = true
        }
    }
    
    private func saveBooks(_ books: [Book]) {
        guard !books.isEmpty else { return }
        
        for book in books {
            modelContext.insert(book)
        }
        
        do {
            try modelContext.save()
            if #available(iOS 14.0, *) {
                AppLogger.log("Saved \(books.count) book(s) to database", level: .info, category: AppLogger.general)
            } else {
                SimpleLogger.log("Saved \(books.count) book(s) to database")
            }
        } catch {
            if #available(iOS 14.0, *) {
                AppLogger.log("Failed to save books: \(error.localizedDescription)", level: .error, category: AppLogger.general)
            } else {
                SimpleLogger.log("Failed to save books: \(error.localizedDescription)")
            }
            showError("Failed to save books: \(error.localizedDescription)")
        }
    }
    
    private func updateBooks(_ books: [Book]) {
        guard !books.isEmpty else { return }
        
        // Books are already in the context (auto-saved), so we just need to save any edits
        do {
            try modelContext.save()
            if #available(iOS 14.0, *) {
                AppLogger.log("Updated \(books.count) book(s) in database", level: .info, category: AppLogger.general)
            } else {
                SimpleLogger.log("Updated \(books.count) book(s) in database")
            }
        } catch {
            if #available(iOS 14.0, *) {
                AppLogger.log("Failed to update books: \(error.localizedDescription)", level: .error, category: AppLogger.general)
            } else {
                SimpleLogger.log("Failed to update books: \(error.localizedDescription)")
            }
            showError("Failed to update books: \(error.localizedDescription)")
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    var onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        picker.allowsEditing = false
        
        // Configure camera
        if sourceType == .camera {
            if UIImagePickerController.isCameraDeviceAvailable(.rear) {
                picker.cameraDevice = .rear
            }
            picker.cameraCaptureMode = .photo
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Camera will use device's current orientation, supporting both landscape and portrait
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            // Dismiss first to prevent multiple presentations
            parent.dismiss()
            
            // Then process image on next run loop
            DispatchQueue.main.async {
                if let image = info[.originalImage] as? UIImage {
                    self.parent.image = image
                    self.parent.onImageSelected(image)
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
        
        // Support all orientations for camera, with landscape preferred
        func navigationController(_ navigationController: UINavigationController, supportedInterfaceOrientationsFor viewController: UIViewController) -> UIInterfaceOrientationMask {
            if parent.sourceType == .camera {
                // Allow all orientations, but landscape is preferred (listed first)
                return [.landscapeLeft, .landscapeRight, .portrait, .portraitUpsideDown]
            }
            return .all
        }
        
        // Set preferred orientation to landscape when camera appears
        func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
            if parent.sourceType == .camera {
                // Try to set preferred orientation to landscape (if orientation lock is off)
                DispatchQueue.main.async {
                    // Check current orientation and suggest landscape if portrait
                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        let currentOrientation = windowScene.effectiveGeometry.interfaceOrientation
                        if currentOrientation.isPortrait {
                            // Attempt to rotate to landscape (only works if orientation lock is off)
                            let landscapeValue = UIInterfaceOrientation.landscapeRight.rawValue
                            UIDevice.current.setValue(landscapeValue, forKey: "orientation")
                        }
                    }
                }
            }
        }
    }
}

struct BookRecognitionResultView: View {
    let books: [Book]
    let onSave: ([Book]) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var editableBooks: [Book]
    
    init(books: [Book], onSave: @escaping ([Book]) -> Void) {
        self.books = books
        self.onSave = onSave
        _editableBooks = State(initialValue: books)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(editableBooks.indices, id: \.self) { index in
                    BookEditRow(book: $editableBooks[index])
                }
            }
            .navigationTitle("Review Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editableBooks)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct BookEditRow: View {
    @Binding var book: Book
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Title", text: $book.title)
                .textFieldStyle(.roundedBorder)
            TextField("Author", text: $book.author)
                .textFieldStyle(.roundedBorder)
            TextField("Publisher (optional)", text: Binding(
                get: { book.publisher ?? "" },
                set: { book.publisher = $0.isEmpty ? nil : $0 }
            ))
            .textFieldStyle(.roundedBorder)
        }
        .padding(.vertical, 4)
    }
}
