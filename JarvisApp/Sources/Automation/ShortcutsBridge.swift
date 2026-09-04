import UIKit
import Intents

class ShortcutsBridge {

    static let predefinedShortcuts: [ShortcutInfo] = [
        ShortcutInfo(name: "Open App", description: "Opens any app by name", category: .apps),
        ShortcutInfo(name: "Set Volume", description: "Sets device volume to a level", category: .settings),
        ShortcutInfo(name: "Toggle WiFi", description: "Turns WiFi on or off", category: .settings),
        ShortcutInfo(name: "Toggle Bluetooth", description: "Turns Bluetooth on or off", category: .settings),
        ShortcutInfo(name: "Toggle Dark Mode", description: "Switches between light and dark mode", category: .settings),
        ShortcutInfo(name: "Toggle Low Power", description: "Toggles Low Power Mode", category: .settings),
        ShortcutInfo(name: "Set Timer", description: "Sets a timer for N minutes", category: .utilities),
        ShortcutInfo(name: "Set Alarm", description: "Creates an alarm", category: .utilities),
        ShortcutInfo(name: "Take Photo", description: "Opens camera and takes a photo", category: .media),
        ShortcutInfo(name: "Play Playlist", description: "Plays a specific playlist", category: .media),
        ShortcutInfo(name: "Get Battery", description: "Returns battery level", category: .info),
        ShortcutInfo(name: "Get IP Address", description: "Returns current IP address", category: .info),
        ShortcutInfo(name: "Speak Text", description: "Speaks text aloud using Siri voice", category: .utilities),
        ShortcutInfo(name: "Create Note", description: "Creates a new note in Notes app", category: .productivity),
        ShortcutInfo(name: "Create Reminder", description: "Creates a new reminder", category: .productivity),
        ShortcutInfo(name: "Create Calendar Event", description: "Adds an event to Calendar", category: .productivity),
        ShortcutInfo(name: "Send Email", description: "Composes and sends an email", category: .communication),
        ShortcutInfo(name: "Make Call", description: "Initiates a phone call", category: .communication),
    ]

    func runShortcut(name: String, input: String? = nil) async -> Bool {
        var urlString = "shortcuts://run-shortcut?name=\(name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name)"
        if let input, !input.isEmpty {
            urlString += "&input=text&text=\(input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input)"
        }

        guard let url = URL(string: urlString) else { return false }

        return await MainActor.run {
            UIApplication.shared.open(url, options: [:]) { _ in }
            return true
        }
    }

    func createShortcutURL(name: String) -> URL? {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        return URL(string: "shortcuts://open-shortcut?name=\(encoded)")
    }
}

struct ShortcutInfo: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let category: ShortcutCategory

    enum ShortcutCategory: String, CaseIterable {
        case apps = "Apps"
        case settings = "Settings"
        case utilities = "Utilities"
        case media = "Media"
        case info = "Info"
        case productivity = "Productivity"
        case communication = "Communication"
    }
}
