import SwiftUI
import SwiftData

@main
struct BookScannerApp: App {
    @StateObject private var authManager = AuthenticationManager()
    
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
