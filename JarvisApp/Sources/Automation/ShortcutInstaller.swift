import UIKit

class ShortcutInstaller {

    struct ShortcutDef {
        let name: String
        let description: String
    }

    let required: [ShortcutDef] = [
        ShortcutDef(name: "Toggle WiFi", description: "Toggles WiFi on/off"),
        ShortcutDef(name: "Toggle Bluetooth", description: "Toggles Bluetooth on/off"),
        ShortcutDef(name: "Toggle Dark Mode", description: "Switches light/dark mode"),
        ShortcutDef(name: "Toggle Low Power", description: "Toggles Low Power Mode"),
        ShortcutDef(name: "Toggle Do Not Disturb", description: "Toggles Do Not Disturb"),
        ShortcutDef(name: "Toggle Airplane Mode", description: "Toggles Airplane Mode"),
        ShortcutDef(name: "Set Timer", description: "Sets a timer (input: minutes)"),
        ShortcutDef(name: "Set Alarm", description: "Sets an alarm (input: time)"),
        ShortcutDef(name: "Open App", description: "Opens any app by name"),
        ShortcutDef(name: "Create Note", description: "Creates a note (input: text)"),
        ShortcutDef(name: "Create Reminder", description: "Creates a reminder (input: text)"),
        ShortcutDef(name: "Create Calendar Event", description: "Creates an event (input: title)"),
        ShortcutDef(name: "Play Music", description: "Plays music (input: search query)"),
        ShortcutDef(name: "Speak Text", description: "Speaks text aloud (input: text)"),
        ShortcutDef(name: "Record Screen", description: "Starts/stops screen recording"),
    ]

    func installAll() {
        // Open Shortcuts app with a prompt to create each one
        // iOS doesn't have a public API to create shortcuts programmatically,
        // but we can open the Shortcuts app and provide guidance
        if let url = URL(string: "shortcuts://") {
            UIApplication.shared.open(url)
        }

        // Store that we've prompted the user
        UserDefaults.standard.set(true, forKey: "shortcuts_install_prompted")

        // Show notification with instructions
        let content = UNMutableNotificationContent()
        content.title = "Jarvis Shortcuts Setup"
        content.body = "Create the shortcuts listed in the app. Each one is just 1-2 actions. Jarvis will guide you through each one."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "shortcut-setup",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    func installShortcut(_ name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        if let url = URL(string: "shortcuts://create-shortcut?name=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    func openShortcut(_ name: String) {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        if let url = URL(string: "shortcuts://open-shortcut?name=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}
