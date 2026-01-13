import SwiftUI

struct ComparisonView: View {
    let ocrBooks: [Book]
    let aiBooks: [Book]
    let onSave: ([Book]) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedBooks: Set<UUID> = []
    
    var body: some View {
        NavigationView {
            List {
                Section("OCR Results (\(ocrBooks.count))") {
                    ForEach(ocrBooks) { book in
                        BookComparisonRow(
                            book: book,
                            isSelected: selectedBooks.contains(book.id),
                            onToggle: {
                                if selectedBooks.contains(book.id) {
                                    selectedBooks.remove(book.id)
                                } else {
                                    selectedBooks.insert(book.id)
                                }
                            }
                        )
                    }
                }
                
                Section("AI Results (\(aiBooks.count))") {
                    ForEach(aiBooks) { book in
                        BookComparisonRow(
                            book: book,
                            isSelected: selectedBooks.contains(book.id),
                            onToggle: {
                                if selectedBooks.contains(book.id) {
                                    selectedBooks.remove(book.id)
                                } else {
                                    selectedBooks.insert(book.id)
                                }
                            }
                        )
                    }
                }
            }
            .navigationTitle("Compare Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save Selected") {
                        let booksToSave = (ocrBooks + aiBooks).filter { selectedBooks.contains($0.id) }
                        onSave(booksToSave)
                        dismiss()
                    }
                    .disabled(selectedBooks.isEmpty)
                }
            }
        }
    }
}

struct BookComparisonRow: View {
    let book: Book
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let publisher = book.publisher {
                        Text(publisher)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
        }
    }
}
