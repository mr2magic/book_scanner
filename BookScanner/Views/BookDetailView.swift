import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @StateObject private var amazonService = AmazonService()
    @State private var showAmazonLookup = false
    @State private var isLookingUp = false
    @State private var showDeleteConfirmation = false
    @State private var showImagePicker = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        Form {
            Section("Book Information") {
                TextField("Title *", text: $book.title)
                TextField("Author *", text: $book.author)
                TextField("Publisher", text: Binding(
                    get: { book.publisher ?? "" },
                    set: { book.publisher = $0.isEmpty ? nil : $0 }
                ))
                TextField("ISBN", text: Binding(
                    get: { book.isbn ?? "" },
                    set: { book.isbn = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.numberPad)
            }
            
            Section("Cover Image") {
                if let imageData = book.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                }
                
                Button("Change Image") {
                    showImagePicker = true
                }
                
                if book.imageData != nil {
                    Button(role: .destructive) {
                        book.imageData = nil
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
                TextEditor(text: Binding(
                    get: { book.notes ?? "" },
                    set: { book.notes = $0.isEmpty ? nil : $0 }
                ))
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
                book.imageData = image.jpegData(compressionQuality: 0.8)
            }
        }
        .onChange(of: book.title) { _, newValue in
            validateBook()
        }
        .onChange(of: book.author) { _, newValue in
            validateBook()
        }
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
    
    private func validateBook() {
        if book.title.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Title is required"
            showValidationError = true
        } else if book.author.trimmingCharacters(in: .whitespaces).isEmpty {
            validationMessage = "Author is required"
            showValidationError = true
        }
        
        // Validate ISBN if provided
        if let isbn = book.isbn, !isbn.isEmpty {
            let cleanedISBN = isbn.replacingOccurrences(of: "-", with: "")
            if cleanedISBN.count != 10 && cleanedISBN.count != 13 {
                validationMessage = "ISBN must be 10 or 13 digits"
                showValidationError = true
            }
        }
    }
}
