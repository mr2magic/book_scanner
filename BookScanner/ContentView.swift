import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CameraView()
                .tabItem {
                    Label("Scan", systemImage: "camera.fill")
                }
                .tag(0)
            
            BookListView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(2)
            
            TestScanView()
                .tabItem {
                    Label("Test", systemImage: "checkmark.circle.fill")
                }
                .tag(3)
            
            TestSuiteView()
                .tabItem {
                    Label("Test Suite", systemImage: "list.bullet.rectangle")
                }
                .tag(4)
        }
    }
}
