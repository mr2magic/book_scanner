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
                        showImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "camera.fill")
                            Text("Take Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Take photo of book spines")
                    
                    Button(action: {
                        showPhotoLibraryPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Choose from Library")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .accessibilityLabel("Choose image from photo library")
                }
                .padding(.horizontal, 40)
                
                if showProcessing {
                    ProgressView("Processing image...")
                        .padding()
                }
                
                // Version number
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
            }
            .navigationTitle("Scan Books")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .camera, onImageSelected: { image in
                    processImage(image)
                })
            }
            .sheet(isPresented: $showPhotoLibraryPicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary, onImageSelected: { image in
                    processImage(image)
                })
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
                        saveBooks(books)
                    }
                } else {
                    BookRecognitionResultView(books: recognizedBooks) { books in
                        saveBooks(books)
                    }
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        Task { @MainActor in
            showProcessing = true
            recognizedBooks = []
            ocrBooks = []
            aiBooks = []
            
            do {
                switch settings.scanMethod {
                case .ocr:
                    let books = try await ocrService.recognizeBooks(from: image)
                    showProcessing = false
                    recognizedBooks = books
                    ocrBooks = books
                    
                    if books.isEmpty {
                        showError("No books detected in image")
                    } else {
                        showResult = true
                    }
                    
                case .ai:
                    let books = try await aiService.recognizeBooks(from: image)
                    showProcessing = false
                    recognizedBooks = books
                    aiBooks = books
                    
                    if books.isEmpty {
                        showError("No books detected in image")
                    } else {
                        showResult = true
                    }
                    
                case .both:
                    async let ocrTask = ocrService.recognizeBooks(from: image)
                    async let aiTask = aiService.recognizeBooks(from: image)
                    
                    let (ocrResult, aiResult) = try await (ocrTask, aiTask)
                    
                    showProcessing = false
                    ocrBooks = ocrResult
                    aiBooks = aiResult
                    
                    if settings.compareResults {
                        showResult = true
                    } else {
                        recognizedBooks = ocrResult + aiResult
                        showResult = true
                    }
                }
            } catch {
                showProcessing = false
                showError(error.localizedDescription)
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
        for book in books {
            modelContext.insert(book)
        }
        try? modelContext.save()
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
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
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
