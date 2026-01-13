import SwiftUI

/// Accessibility helpers for VoiceOver and other assistive technologies
struct AccessibilityHelpers {
    /// Create accessibility label for book
    static func bookLabel(title: String, author: String, publisher: String?) -> String {
        var label = "Book: \(title) by \(author)"
        if let publisher = publisher {
            label += ", published by \(publisher)"
        }
        return label
    }
    
    /// Create accessibility hint for actions
    static func actionHint(for action: String) -> String {
        switch action.lowercased() {
        case "scan":
            return "Double tap to scan books from camera or photo library"
        case "add":
            return "Double tap to manually add a new book"
        case "edit":
            return "Double tap to edit book details"
        case "delete":
            return "Double tap to delete this book"
        case "export":
            return "Double tap to export your library to CSV"
        default:
            return "Double tap to \(action)"
        }
    }
}

/// View modifier for accessibility
struct AccessibilityModifier: ViewModifier {
    let label: String
    let hint: String?
    let trait: AccessibilityTraits?
    
    func body(content: Content) -> some View {
        content
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(trait ?? [])
    }
}

extension View {
    func accessible(label: String, hint: String? = nil, trait: AccessibilityTraits? = nil) -> some View {
        modifier(AccessibilityModifier(label: label, hint: hint, trait: trait))
    }
}
