import SwiftUI

class AppSettings: ObservableObject {
    @Published var scanMethod: ScanMethod = .ocr
    @Published var amazonAPIKey: String = ""
    @Published var amazonSecretKey: String = ""
    @Published var amazonAssociateTag: String = ""
    @Published var compareResults: Bool = true
    
    enum ScanMethod: String, CaseIterable {
        case ocr = "OCR"
        case ai = "AI"
        case both = "Both"
    }
    
    init() {
        loadSettings()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(scanMethod.rawValue, forKey: "scanMethod")
        UserDefaults.standard.set(amazonAPIKey, forKey: "amazonAPIKey")
        UserDefaults.standard.set(amazonSecretKey, forKey: "amazonSecretKey")
        UserDefaults.standard.set(amazonAssociateTag, forKey: "amazonAssociateTag")
        UserDefaults.standard.set(compareResults, forKey: "compareResults")
    }
    
    private func loadSettings() {
        if let methodString = UserDefaults.standard.string(forKey: "scanMethod"),
           let method = ScanMethod(rawValue: methodString) {
            scanMethod = method
        }
        amazonAPIKey = UserDefaults.standard.string(forKey: "amazonAPIKey") ?? ""
        amazonSecretKey = UserDefaults.standard.string(forKey: "amazonSecretKey") ?? ""
        amazonAssociateTag = UserDefaults.standard.string(forKey: "amazonAssociateTag") ?? ""
        compareResults = UserDefaults.standard.bool(forKey: "compareResults")
    }
}

struct SettingsView: View {
    @StateObject private var settings = AppSettings()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Scanning Method") {
                    Picker("Method", selection: $settings.scanMethod) {
                        ForEach(AppSettings.ScanMethod.allCases, id: \.self) { method in
                            Text(method.rawValue).tag(method)
                        }
                    }
                    .onChange(of: settings.scanMethod) { _, _ in
                        settings.saveSettings()
                    }
                    
                    Toggle("Compare OCR vs AI Results", isOn: $settings.compareResults)
                        .onChange(of: settings.compareResults) { _, _ in
                            settings.saveSettings()
                        }
                }
                
                Section("Amazon Product Advertising API") {
                    TextField("Access Key ID", text: $settings.amazonAPIKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: settings.amazonAPIKey) { _, _ in
                            settings.saveSettings()
                        }
                    
                    SecureField("Secret Access Key", text: $settings.amazonSecretKey)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: settings.amazonSecretKey) { _, _ in
                            settings.saveSettings()
                        }
                    
                    TextField("Associate Tag", text: $settings.amazonAssociateTag)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .onChange(of: settings.amazonAssociateTag) { _, _ in
                            settings.saveSettings()
                        }
                    
                    Text("Get credentials from Amazon Product Advertising API")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
