import SwiftUI

@main
struct JarvisApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isConnected = false
    @Published var serverURL: String = UserDefaults.standard.string(forKey: "serverURL") ?? "" {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }
    @Published var apiKey: String = UserDefaults.standard.string(forKey: "apiKey") ?? "" {
        didSet { UserDefaults.standard.set(apiKey, forKey: "apiKey") }
    }

    lazy var jarvisService: JarvisService = JarvisService(appState: self)
    lazy var automationEngine: AutomationEngine = AutomationEngine()
    lazy var screenCaptureService: ScreenCaptureService = ScreenCaptureService()
}
