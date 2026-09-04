import SwiftUI
import UserNotifications
import AVFoundation

@main
struct JarvisApp: App {
    @StateObject private var jarvis = JarvisBrain()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        UIDevice.current.isBatteryMonitoringEnabled = true
        AVAudioApplication.requestRecordPermission { _ in }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if jarvis.hasCompletedSetup {
                    JarvisRootView()
                } else {
                    SetupWizardView()
                }
            }
            .environmentObject(jarvis)
        }
    }
}
