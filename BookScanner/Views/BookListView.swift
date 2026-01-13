import SwiftUI
import SwiftData

struct BookListView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showExportSheet = false
    
    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        }
        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            book.author.localizedCaseInsensitiveContains(searchText) ||
            (book.publisher?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if filteredBooks.isEmpty {
                    ContentUnavailableView(
                        "No Books",
                        systemImage: "books.vertical",
                        description: Text(searchText.isEmpty ? "Start by scanning your books" : "No books match your search")
                    )
                } else {
                    List {
                        ForEach(filteredBooks) { book in
                            NavigationLink(destination: BookDetailView(book: book)) {
                                BookRow(book: book)
                            }
                        }
                        .onDelete { indexSet in
                            deleteBooks(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("My Library")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showExportSheet = true
                        }) {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(books: books)
            }
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let book = filteredBooks[index]
                modelContext.delete(book)
            }
            try? modelContext.save()
        }
    }
}

struct BookRow: View {
    let book: Book
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)
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
            if let price = book.amazonPrice {
                VStack(alignment: .trailing) {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
