import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var author = ""
    @State private var publisher = ""
    @State private var isbn = ""
    @State private var notes = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Book Information") {
                    TextField("Title *", text: $title)
                    TextField("Author *", text: $author)
                    TextField("Publisher", text: $publisher)
                    TextField("ISBN", text: $isbn)
                        .keyboardType(.numberPad)
                }
                
                Section("Cover Image") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                    
                    Button("Select Image") {
                        showImagePicker = true
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveBook()
                    }
                    .disabled(title.isEmpty || author.isEmpty)
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage, sourceType: .photoLibrary) { image in
                    selectedImage = image
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func saveBook() {
        // Validate
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Title is required"
            showValidationError = true
            return
        }
        
        guard !author.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationMessage = "Author is required"
            showValidationError = true
            return
        }
        
        // Validate ISBN if provided
        if !isbn.isEmpty {
            let cleanedISBN = isbn.replacingOccurrences(of: "-", with: "")
            if cleanedISBN.count != 10 && cleanedISBN.count != 13 {
                validationMessage = "ISBN must be 10 or 13 digits"
                showValidationError = true
                return
            }
        }
        
        // Create book
        let book = Book(
            title: title.trimmingCharacters(in: .whitespaces),
            author: author.trimmingCharacters(in: .whitespaces),
            publisher: publisher.isEmpty ? nil : publisher.trimmingCharacters(in: .whitespaces),
            isbn: isbn.isEmpty ? nil : isbn.trimmingCharacters(in: .whitespaces),
            dateAdded: Date(),
            imageData: selectedImage?.jpegData(compressionQuality: 0.8),
            amazonPrice: nil,
            amazonURL: nil,
            notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespaces)
        )
        
        modelContext.insert(book)
        try? modelContext.save()
        dismiss()
    }
}
