import SwiftUI
import SwiftData

enum SortOption: String, CaseIterable {
    case dateAdded = "Date Added"
    case title = "Title"
    case author = "Author"
    case publisher = "Publisher"
}

enum SortOrder: String, CaseIterable {
    case ascending = "Ascending"
    case descending = "Descending"
}

struct BookListView: View {
    @Query(sort: \Book.dateAdded, order: .reverse) private var allBooks: [Book]
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var showExportSheet = false
    @State private var showAddBook = false
    @State private var sortOption: SortOption = .dateAdded
    @State private var sortOrder: SortOrder = .descending
    @State private var selectedBooks: Set<UUID> = []
    @State private var isEditMode = false
    @State private var showBatchDeleteConfirmation = false
    
    var filteredAndSortedBooks: [Book] {
        var books = allBooks
        
        // Filter by search
        if !searchText.isEmpty {
            books = books.filter { book in
                book.title.localizedCaseInsensitiveContains(searchText) ||
                book.author.localizedCaseInsensitiveContains(searchText) ||
                (book.publisher?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (book.isbn?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Sort
        books.sort { book1, book2 in
            let comparison: ComparisonResult
            switch sortOption {
            case .dateAdded:
                comparison = book1.dateAdded.compare(book2.dateAdded)
            case .title:
                comparison = book1.title.localizedCompare(book2.title)
            case .author:
                comparison = book1.author.localizedCompare(book2.author)
            case .publisher:
                let pub1 = book1.publisher ?? ""
                let pub2 = book2.publisher ?? ""
                comparison = pub1.localizedCompare(pub2)
            }
            
            return sortOrder == .ascending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
        
        return books
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if filteredAndSortedBooks.isEmpty {
                    VStack(spacing: 20) {
                        ContentUnavailableView(
                            "No Books",
                            systemImage: "books.vertical",
                            description: Text(searchText.isEmpty ? "Start by scanning your books or add one manually" : "No books match your search")
                        )
                        if searchText.isEmpty {
                            Button("Add Book") {
                                showAddBook = true
                            }
                            .buttonStyle(.borderedProminent)
                            .padding()
                        }
                    }
                } else {
                    List {
                        // Sort and filter controls
                        Section {
                            Picker("Sort By", selection: $sortOption) {
                                ForEach(SortOption.allCases, id: \.self) { option in
                                    Text(option.rawValue).tag(option)
                                }
                            }
                            
                            Picker("Order", selection: $sortOrder) {
                                ForEach(SortOrder.allCases, id: \.self) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        }
                        
                        // Books list
                        ForEach(filteredAndSortedBooks) { book in
                            if isEditMode {
                                BookRowSelectable(book: book, isSelected: selectedBooks.contains(book.id)) {
                                    toggleSelection(book: book)
                                }
                            } else {
                                NavigationLink(destination: BookDetailView(book: book)) {
                                    BookRow(book: book)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        deleteBook(book)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    NavigationLink(destination: BookDetailView(book: book)) {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            deleteBooks(at: indexSet)
                        }
                    }
                }
            }
            .navigationTitle("My Library (\(filteredAndSortedBooks.count))")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    if isEditMode {
                        Button("Cancel") {
                            isEditMode = false
                            selectedBooks.removeAll()
                        }
                        
                        if !selectedBooks.isEmpty {
                            Button("Delete (\(selectedBooks.count))") {
                                showBatchDeleteConfirmation = true
                            }
                            .foregroundColor(.red)
                        }
                    } else {
                        Button(action: {
                            isEditMode = true
                        }) {
                            Label("Select", systemImage: "checklist")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showAddBook = true
                    }) {
                        Label("Add Book", systemImage: "plus")
                    }
                    
                    Menu {
                        Button(action: {
                            showExportSheet = true
                        }) {
                            Label("Export to CSV", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(books: allBooks)
            }
            .sheet(isPresented: $showAddBook) {
                AddBookView()
            }
            .alert("Delete Books", isPresented: $showBatchDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteSelectedBooks()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedBooks.count) book(s)? This action cannot be undone.")
            }
        }
    }
    
    private func toggleSelection(book: Book) {
        if selectedBooks.contains(book.id) {
            selectedBooks.remove(book.id)
        } else {
            selectedBooks.insert(book.id)
        }
    }
    
    private func deleteSelectedBooks() {
        withAnimation {
            for bookId in selectedBooks {
                if let book = allBooks.first(where: { $0.id == bookId }) {
                    modelContext.delete(book)
                }
            }
            selectedBooks.removeAll()
            isEditMode = false
            try? modelContext.save()
        }
    }
    
    private func deleteBook(_ book: Book) {
        withAnimation {
            modelContext.delete(book)
            try? modelContext.save()
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let book = filteredAndSortedBooks[index]
                modelContext.delete(book)
            }
            try? modelContext.save()
        }
    }
}

struct BookRow: View {
    let book: Book
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Book thumbnail if available
            if let imageData = book.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 90)
                    .cornerRadius(8)
                    .clipped()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 90)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    )
            }
            
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
                if let isbn = book.isbn {
                    Text("ISBN: \(isbn)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                if let price = book.amazonPrice {
                    Text(price)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
                Text(book.dateAdded, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

struct BookRowSelectable: View {
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
                        .lineLimit(2)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
