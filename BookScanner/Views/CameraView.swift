import SwiftUI
import AVFoundation
import PhotosUI

struct CameraView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var ocrService = OCRService()
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var showProcessing = false
    @State private var showResult = false
    @State private var recognizedBooks: [Book] = []
    
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
                .padding(.horizontal, 40)
                
                if showProcessing {
                    ProgressView("Processing image...")
                        .padding()
                }
            }
            .navigationTitle("Scan Books")
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, onImageSelected: { image in
                    processImage(image)
                })
            }
            .sheet(isPresented: $showResult) {
                BookRecognitionResultView(books: recognizedBooks) { books in
                    saveBooks(books)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        showProcessing = true
        ocrService.recognizeBooks(from: image) { books in
            DispatchQueue.main.async {
                showProcessing = false
                recognizedBooks = books
                showResult = true
            }
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
    var onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
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
