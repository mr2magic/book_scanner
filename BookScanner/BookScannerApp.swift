import SwiftUI
import SwiftData

@main
struct BookScannerApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        // Configure app-wide orientation support
        // Default to landscape for camera, but allow all orientations
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isAuthenticated {
                ContentView()
                    .modelContainer(for: Book.self)
            } else {
                AuthenticationView()
                    .environmentObject(authManager)
            }
        }
    }
}
