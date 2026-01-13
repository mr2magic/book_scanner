import Foundation

/// Localization support for future internationalization
enum LocalizedStrings {
    // MARK: - General
    static let appName = NSLocalizedString("app.name", comment: "App name")
    static let ok = NSLocalizedString("general.ok", comment: "OK button")
    static let cancel = NSLocalizedString("general.cancel", comment: "Cancel button")
    static let save = NSLocalizedString("general.save", comment: "Save button")
    static let delete = NSLocalizedString("general.delete", comment: "Delete button")
    static let edit = NSLocalizedString("general.edit", comment: "Edit button")
    
    // MARK: - Books
    static let bookTitle = NSLocalizedString("book.title", comment: "Book title")
    static let bookAuthor = NSLocalizedString("book.author", comment: "Book author")
    static let bookPublisher = NSLocalizedString("book.publisher", comment: "Book publisher")
    static let bookISBN = NSLocalizedString("book.isbn", comment: "Book ISBN")
    static let bookNotes = NSLocalizedString("book.notes", comment: "Book notes")
    
    // MARK: - Errors
    static func errorMessage(_ error: AppError) -> String {
        return error.errorDescription ?? NSLocalizedString("error.unknown", comment: "Unknown error")
    }
    
    static func errorRecovery(_ error: AppError) -> String {
        return error.recoverySuggestion ?? NSLocalizedString("error.recovery", comment: "Error recovery suggestion")
    }
}
