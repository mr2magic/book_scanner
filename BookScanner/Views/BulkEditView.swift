import SwiftUI
import SwiftData

struct BulkEditView: View {
    let selectedBookIds: Set<UUID>
    let allBooks: [Book]
    let onSave: ([Book]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var editedPublisher: String = ""
    @State private var editedNotes: String = ""
    @State private var clearPublisher: Bool = false
    @State private var clearNotes: Bool = false
    @State private var showValidationError = false
    @State private var validationMessage: String = ""
    
    private var selectedBooks: [Book] {
        allBooks.filter { selectedBookIds.contains($0.id) }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("Editing \(selectedBooks.count) book(s)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                
                Section("Publisher") {
                    Toggle("Clear Publisher", isOn: $clearPublisher)
                    
                    if !clearPublisher {
                        TextField("Publisher", text: $editedPublisher)
                            .disabled(clearPublisher)
                    }
                    
                    Text("Leave empty to keep existing values")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Notes") {
                    Toggle("Clear Notes", isOn: $clearNotes)
                    
                    if !clearNotes {
                        TextEditor(text: $editedNotes)
                            .frame(minHeight: 100)
                            .disabled(clearNotes)
                    }
                    
                    Text("Leave empty to keep existing values")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section {
                    Text("Changes will be applied to all \(selectedBooks.count) selected book(s). Fields left empty will preserve existing values.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Bulk Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .alert("Validation Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private func saveChanges() {
        // Update existing books directly
        for book in selectedBooks {
            // Update publisher
            if clearPublisher {
                book.publisher = nil
            } else if !editedPublisher.isEmpty {
                book.publisher = editedPublisher.trimmingCharacters(in: .whitespaces)
            }
            // If editedPublisher is empty and clearPublisher is false, keep existing value
            
            // Update notes
            if clearNotes {
                book.notes = nil
            } else if !editedNotes.isEmpty {
                book.notes = editedNotes.trimmingCharacters(in: .whitespaces)
            }
            // If editedNotes is empty and clearNotes is false, keep existing value
        }
        
        onSave(selectedBooks)
        dismiss()
    }
}
