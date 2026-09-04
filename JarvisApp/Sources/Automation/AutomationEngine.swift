import UIKit

class AutomationEngine {

    func execute(action: DeviceAction) async -> ActionResult {
        switch action.type {
        case .openApp:
            return await openApp(action.parameters)
        case .typeText:
            return typeText(action.parameters)
        case .openURL:
            return await openURL(action.parameters)
        case .goHome:
            return goHome()
        case .setBrightness:
            return setBrightness(action.parameters)
        case .search:
            return await search(action.parameters)
        case .runShortcut:
            return await runShortcut(action.parameters)
        case .sendMessage:
            return await sendMessage(action.parameters)
        case .openSettings:
            return await openSettings(action.parameters)
        case .notification:
            return await showNotification(action.parameters)
        case .wait:
            return await waitAction(action.parameters)
        case .copyText:
            return copyText(action.parameters)
        case .pasteText:
            return pasteText()
        case .setVolume:
            return setVolume(action.parameters)
        case .openControlCenter:
            return ActionResult(success: true, message: "Hint: Swipe down from top-right corner")
        case .lockScreen:
            return ActionResult(success: true, message: "Hint: Press the power button to lock")
        case .launchSiri:
            return ActionResult(success: true, message: "Hint: Long-press the home/power button for Siri")
        default:
            return ActionResult(success: false, message: "Action '\(action.type.rawValue)' not directly supported. Use Shortcuts for advanced control.")
        }
    }

    func executeAll(actions: [DeviceAction]) async -> [ActionResult] {
        var results: [ActionResult] = []
        for action in actions {
            let result = await execute(action: action)
            results.append(result)
            if !result.success { break }
        }
        return results
    }
}

struct ActionResult {
    let success: Bool
    let message: String
}

// MARK: - Action Implementations
extension AutomationEngine {

    private func openApp(_ params: [String: ActionValue]) async -> ActionResult {
        guard let appName = params["name"]?.stringValue else {
            return ActionResult(success: false, message: "No app name provided")
        }

        let urlSchemes: [String: String] = [
            "safari": "https://",
            "messages": "sms://",
            "mail": "mailto:",
            "maps": "maps://",
            "music": "music://",
            "photos": "photos-redirect://",
            "camera": "camera://",
            "calendar": "calshow://",
            "notes": "mobilenotes://",
            "reminders": "x-apple-reminderkit://",
            "clock": "clock-worldclock://",
            "weather": "weather://",
            "calculator": "calc://",
            "settings": "App-prefs://",
            "files": "shareddocuments://",
            "facetime": "facetime://",
            "shortcuts": "shortcuts://",
            "app store": "itms-apps://",
            "youtube": "youtube://",
            "twitter": "twitter://",
            "x": "twitter://",
            "instagram": "instagram://",
            "whatsapp": "whatsapp://",
            "telegram": "tg://",
            "spotify": "spotify://",
            "netflix": "nflx://",
            "tiktok": "snssdk1233://",
            "snapchat": "snapchat://",
            "discord": "discord://",
            "slack": "slack://",
            "zoom": "zoomus://",
            "chrome": "googlechrome://",
            "gmail": "googlegmail://",
            "google maps": "comgooglemaps://",
            "google drive": "googledrive://",
            "notion": "notion://",
            "reddit": "reddit://",
            "pinterest": "pinterest://",
            "amazon": "com.amazon.mobile.shopping://",
        ]

        let key = appName.lowercased()
        if let scheme = urlSchemes[key], let url = URL(string: scheme) {
            return await MainActor.run {
                UIApplication.shared.open(url, options: [:]) { _ in }
                return ActionResult(success: true, message: "Opening \(appName)")
            }
        }

        let searchURL = URL(string: "shortcuts://run-shortcut?name=Open%20App&input=\(appName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appName)")!
        return await MainActor.run {
            UIApplication.shared.open(searchURL, options: [:]) { _ in }
            return ActionResult(success: true, message: "Attempting to open \(appName) via Shortcuts")
        }
    }

    private func typeText(_ params: [String: ActionValue]) -> ActionResult {
        guard let text = params["text"]?.stringValue else {
            return ActionResult(success: false, message: "No text provided")
        }
        UIPasteboard.general.string = text
        return ActionResult(success: true, message: "Text '\(text)' copied to clipboard. Paste it in the target field.")
    }

    private func openURL(_ params: [String: ActionValue]) async -> ActionResult {
        guard let urlString = params["url"]?.stringValue, let url = URL(string: urlString) else {
            return ActionResult(success: false, message: "Invalid URL")
        }
        return await MainActor.run {
            UIApplication.shared.open(url, options: [:]) { _ in }
            return ActionResult(success: true, message: "Opening \(urlString)")
        }
    }

    private func goHome() -> ActionResult {
        // iOS doesn't allow programmatic home press, but we can guide via Shortcuts
        return ActionResult(success: true, message: "Hint: Swipe up from the bottom edge to go home")
    }

    private func setBrightness(_ params: [String: ActionValue]) -> ActionResult {
        guard let level = params["level"]?.numberValue else {
            return ActionResult(success: false, message: "No brightness level")
        }
        let clamped = max(0, min(1, CGFloat(level)))
        UIScreen.main.brightness = clamped
        return ActionResult(success: true, message: "Brightness set to \(Int(clamped * 100))%")
    }

    private func setVolume(_ params: [String: ActionValue]) -> ActionResult {
        // Volume can be controlled via Shortcuts
        guard let level = params["level"]?.numberValue else {
            return ActionResult(success: false, message: "No volume level")
        }
        return ActionResult(success: true, message: "Use the 'Set Volume' shortcut to set volume to \(Int(level * 100))%")
    }

    private func search(_ params: [String: ActionValue]) async -> ActionResult {
        guard let query = params["query"]?.stringValue else {
            return ActionResult(success: false, message: "No search query")
        }
        let engine = params["engine"]?.stringValue ?? "google"
        let searchURL: String
        switch engine.lowercased() {
        case "youtube":
            searchURL = "https://www.youtube.com/results?search_query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        case "maps":
            searchURL = "maps://?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        case "app store":
            searchURL = "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?term=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        default:
            searchURL = "https://www.google.com/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"
        }

        if let url = URL(string: searchURL) {
            return await MainActor.run {
                UIApplication.shared.open(url, options: [:]) { _ in }
                return ActionResult(success: true, message: "Searching for '\(query)'")
            }
        }
        return ActionResult(success: false, message: "Failed to create search URL")
    }

    private func runShortcut(_ params: [String: ActionValue]) async -> ActionResult {
        guard let name = params["name"]?.stringValue else {
            return ActionResult(success: false, message: "No shortcut name")
        }
        let input = params["input"]?.stringValue ?? ""
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let inputEncoded = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input

        var urlString = "shortcuts://run-shortcut?name=\(encoded)"
        if !input.isEmpty {
            urlString += "&input=text&text=\(inputEncoded)"
        }

        if let url = URL(string: urlString) {
            return await MainActor.run {
                UIApplication.shared.open(url, options: [:]) { _ in }
                return ActionResult(success: true, message: "Running shortcut '\(name)'")
            }
        }
        return ActionResult(success: false, message: "Failed to run shortcut")
    }

    private func sendMessage(_ params: [String: ActionValue]) async -> ActionResult {
        guard let to = params["to"]?.stringValue else {
            return ActionResult(success: false, message: "No recipient")
        }
        let body = params["body"]?.stringValue ?? ""
        let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        let toEncoded = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to

        if let url = URL(string: "sms:\(toEncoded)&body=\(bodyEncoded)") {
            return await MainActor.run {
                UIApplication.shared.open(url, options: [:]) { _ in }
                return ActionResult(success: true, message: "Opening message to \(to)")
            }
        }
        return ActionResult(success: false, message: "Failed to open Messages")
    }

    private func openSettings(_ params: [String: ActionValue]) async -> ActionResult {
        let section = params["section"]?.stringValue?.lowercased() ?? ""
        let settingsURLs: [String: String] = [
            "wifi": "App-prefs:WIFI",
            "bluetooth": "App-prefs:Bluetooth",
            "cellular": "App-prefs:MOBILE_DATA_SETTINGS_ID",
            "display": "App-prefs:DISPLAY",
            "sounds": "App-prefs:Sounds",
            "notifications": "App-prefs:NOTIFICATIONS_ID",
            "general": "App-prefs:General",
            "privacy": "App-prefs:Privacy",
            "battery": "App-prefs:BATTERY_USAGE",
            "storage": "App-prefs:CASTLE",
            "wallpaper": "App-prefs:Wallpaper",
            "accessibility": "App-prefs:ACCESSIBILITY",
        ]

        let urlString = settingsURLs[section] ?? "App-prefs:"
        if let url = URL(string: urlString) {
            return await MainActor.run {
                UIApplication.shared.open(url, options: [:]) { _ in }
                return ActionResult(success: true, message: "Opening Settings" + (section.isEmpty ? "" : " > \(section)"))
            }
        }
        return ActionResult(success: false, message: "Failed to open Settings")
    }

    private func showNotification(_ params: [String: ActionValue]) async -> ActionResult {
        let title = params["title"]?.stringValue ?? "Jarvis"
        let body = params["body"]?.stringValue ?? ""

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return ActionResult(success: true, message: "Notification sent")
        } catch {
            return ActionResult(success: false, message: "Failed to send notification: \(error.localizedDescription)")
        }
    }

    private func waitAction(_ params: [String: ActionValue]) async -> ActionResult {
        let seconds = params["seconds"]?.numberValue ?? 1
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        return ActionResult(success: true, message: "Waited \(seconds) seconds")
    }

    private func copyText(_ params: [String: ActionValue]) -> ActionResult {
        guard let text = params["text"]?.stringValue else {
            return ActionResult(success: false, message: "No text to copy")
        }
        UIPasteboard.general.string = text
        return ActionResult(success: true, message: "Copied to clipboard")
    }

    private func pasteText() -> ActionResult {
        if let text = UIPasteboard.general.string {
            return ActionResult(success: true, message: "Clipboard contains: \(text)")
        }
        return ActionResult(success: false, message: "Clipboard is empty")
    }
}
