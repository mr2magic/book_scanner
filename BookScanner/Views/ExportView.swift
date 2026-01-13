import SwiftUI

struct ExportView: View {
    let books: [Book]
    @Environment(\.dismiss) var dismiss
    @StateObject private var csvService = CSVExportService()
    @State private var showShareSheet = false
    @State private var fileURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Export \(books.count) books to CSV")
                    .font(.headline)
                    .padding()
                
                Button(action: {
                    exportToCSV()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export CSV")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = fileURL {
                    ShareSheet(activityItems: [url])
                }
            }
        }
    }
    
    private func exportToCSV() {
        if let url = csvService.exportBooks(books) {
            fileURL = url
            showShareSheet = true
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
