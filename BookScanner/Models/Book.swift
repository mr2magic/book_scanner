import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String
    var publisher: String?
    var isbn: String?
    var dateAdded: Date
    var imageData: Data?
    var amazonPrice: String?
    var amazonURL: String?
    var notes: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        publisher: String? = nil,
        isbn: String? = nil,
        dateAdded: Date = Date(),
        imageData: Data? = nil,
        amazonPrice: String? = nil,
        amazonURL: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.publisher = publisher
        self.isbn = isbn
        self.dateAdded = dateAdded
        self.imageData = imageData
        self.amazonPrice = amazonPrice
        self.amazonURL = amazonURL
        self.notes = notes
    }
}
