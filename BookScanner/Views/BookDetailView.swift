import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var amazonService = AmazonService()
    @State private var showAmazonLookup = false
    @State private var isLookingUp = false
    @State private var showDeleteConfirmation = false
    @State private var showImagePicker = false
    @State private var showValidationError = false
    @State private var validationMessage: String = ""
    @State private var hasSaved: Bool = false
    
    // Local state for editing (only saved when user clicks Save)
    @State private var editedTitle: String = ""
    @State private var editedAuthor: String = ""
    @State private var editedPublisher: String = ""
    @State private var editedISBN: String = ""
    @State private var editedNotes: String = ""
    @State private var editedImageData: Data? = nil
    
    // Store original values to revert on cancel
    @State private var originalTitle: String = ""
    @State private var originalAuthor: String = ""
    @State private var originalPublisher: String? = nil
    @State private var originalISBN: String? = nil
    @State private var originalNotes: String? = nil
    @State private var originalImageData: Data? = nil
    
    var body: some View {
        Form {
            Section("Book Information") {
                TextField("Title *", text: $editedTitle)
                TextField("Author *", text: $editedAuthor)
                TextField("Publisher", text: $editedPublisher)
                TextField("ISBN", text: $editedISBN)
                    .keyboardType(.numberPad)
            }
            
            Section("Cover Image") {
                if let imageData = editedImageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }
                
                Button("Change Image") {
                    showImagePicker = true
                }
                
                if editedImageData != nil {
                    Button(role: .destructive) {
                        editedImageData = nil
                    } label: {
                        Text("Remove Image")
                    }
                }
            }
            
            Section("Amazon Information") {
                if let price = book.amazonPrice {
                    HStack {
                        Text("Price")
                        Spacer()
                        Text(price)
                            .foregroundColor(.green)
                    }
                }
                
                if let urlString = book.amazonURL, let url = URL(string: urlString) {
                    Link("View on Amazon", destination: url)
                }
                
                Button(action: {
                    lookupOnAmazon()
                }) {
                    HStack {
                        if isLookingUp {
                            ProgressView()
                        } else {
                            Image(systemName: "magnifyingglass")
                        }
                        Text("Lookup on Amazon")
                    }
                }
                .disabled(isLookingUp)
            }
            
            Section("Notes") {
                TextEditor(text: $editedNotes)
                    .frame(minHeight: 100)
            }
            
            Section {
                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete Book")
                    }
                }
            }
        }
        .navigationTitle("Book Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveBook()
                }
            }
        }
        .alert("Delete Book", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteBook()
            }
        } message: {
            Text("Are you sure you want to delete this book? This action cannot be undone.")
        }
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(validationMessage)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: .constant(nil), sourceType: .photoLibrary) { image in
                editedImageData = image.jpegData(compressionQuality: 0.8)
            }
        }
        .onAppear {
            // Initialize local state from book when view appears
            loadBookData()
        }
        .onDisappear {
            // Revert changes if user navigates back without saving
            if !hasSaved {
                revertChanges()
            }
        }
    }
    
    private func loadBookData() {
        // Store original values
        originalTitle = book.title
        originalAuthor = book.author
        originalPublisher = book.publisher
        originalISBN = book.isbn
        originalNotes = book.notes
        originalImageData = book.imageData
        
        // Initialize edited values
        editedTitle = book.title
        editedAuthor = book.author
        editedPublisher = book.publisher ?? ""
        editedISBN = book.isbn ?? ""
        editedNotes = book.notes ?? ""
        editedImageData = book.imageData
        
        // Reset save flag
        hasSaved = false
    }
    
    private func revertChanges() {
        // Revert book to original values
        book.title = originalTitle
        book.author = originalAuthor
        book.publisher = originalPublisher
        book.isbn = originalISBN
        book.notes = originalNotes
        book.imageData = originalImageData
        
        // Discard any unsaved changes in the model context
        modelContext.rollback()
    }
    
    private func lookupOnAmazon() {
        isLookingUp = true
        amazonService.lookupBook(title: book.title, author: book.author) { result in
            DispatchQueue.main.async {
                isLookingUp = false
                switch result {
                case .success(let info):
                    book.amazonPrice = info.price
                    book.amazonURL = info.url
                case .failure(let error):
                    print("Amazon lookup failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func deleteBook() {
        modelContext.delete(book)
        try? modelContext.save()
    }
    
    private func saveBook() {
        // Validate before saving
        if editedTitle.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Title is required"
            showValidationError = true
            return
        }
        
        if editedAuthor.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Author is required"
            showValidationError = true
            return
        }
        
        // Validate ISBN if provided
        if !editedISBN.isEmpty {
            let cleanedISBN = editedISBN.replacingOccurrences(of: "-", with: "")
            if cleanedISBN.count != 10 && cleanedISBN.count != 13 {
                validationMessage = "ISBN must be 10 or 13 digits"
                showValidationError = true
                return
            }
        }
        
        // Apply edited values to book model
        book.title = editedTitle.trimmingCharacters(in: .whitespaces)
        book.author = editedAuthor.trimmingCharacters(in: .whitespaces)
        book.publisher = editedPublisher.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editedPublisher.trimmingCharacters(in: .whitespaces)
        book.isbn = editedISBN.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editedISBN.trimmingCharacters(in: .whitespaces)
        book.notes = editedNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editedNotes.trimmingCharacters(in: .whitespaces)
        book.imageData = editedImageData
        
        // Save changes
        do {
            try modelContext.save()
            hasSaved = true
            
            // Update original values after successful save
            originalTitle = book.title
            originalAuthor = book.author
            originalPublisher = book.publisher
            originalISBN = book.isbn
            originalNotes = book.notes
            originalImageData = book.imageData
        } catch {
            validationMessage = "Failed to save: \(error.localizedDescription)"
            showValidationError = true
        }
    }
}
