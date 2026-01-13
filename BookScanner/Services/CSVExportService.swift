import Foundation

struct CSVExportService {
    func exportBooks(_ books: [Book]) -> URL? {
        let fileName = "book_catalog_\(Date().timeIntervalSince1970).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var csvContent = "Title,Author,Publisher,ISBN,Date Added,Amazon Price,Amazon URL,Notes\n"
        
        for book in books {
            let title = escapeCSV(book.title)
            let author = escapeCSV(book.author)
            let publisher = escapeCSV(book.publisher ?? "")
            let isbn = escapeCSV(book.isbn ?? "")
            let dateAdded = DateFormatter.csvFormatter.string(from: book.dateAdded)
            let amazonPrice = escapeCSV(book.amazonPrice ?? "")
            let amazonURL = escapeCSV(book.amazonURL ?? "")
            let notes = escapeCSV(book.notes ?? "")
            
            csvContent += "\(title),\(author),\(publisher),\(isbn),\(dateAdded),\(amazonPrice),\(amazonURL),\(notes)\n"
        }
        
        do {
            try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("CSV export error: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func escapeCSV(_ string: String) -> String {
        if string.contains(",") || string.contains("\"") || string.contains("\n") {
            return "\"" + string.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return string
    }
}

extension DateFormatter {
    static let csvFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}
