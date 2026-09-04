import SwiftUI
import UserNotifications

@main
struct JarvisApp: App {
    @StateObject private var jarvis = JarvisBrain()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    var body: some Scene {
        WindowGroup {
            JarvisRootView()
                .environmentObject(jarvis)
                .preferredColorScheme(jarvis.forcedTheme)
        }
    }
}
