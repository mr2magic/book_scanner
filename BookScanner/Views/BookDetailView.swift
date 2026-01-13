import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext
    @StateObject private var amazonService = AmazonService()
    @State private var showAmazonLookup = false
    @State private var isLookingUp = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        Form {
            Section("Book Information") {
                TextField("Title", text: $book.title)
                TextField("Author", text: $book.author)
                TextField("Publisher", text: Binding(
                    get: { book.publisher ?? "" },
                    set: { book.publisher = $0.isEmpty ? nil : $0 }
                ))
                TextField("ISBN", text: Binding(
                    get: { book.isbn ?? "" },
                    set: { book.isbn = $0.isEmpty ? nil : $0 }
                ))
            }
            
            if let imageData = book.imageData, let uiImage = UIImage(data: imageData) {
                Section("Cover Image") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
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
}
