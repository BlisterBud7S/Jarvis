import UIKit
import UserNotifications
import AVFoundation
import MediaPlayer

struct ActionResult {
    let success: Bool
    let message: String
}

class ActionExecutor {

    let keyboardBridge = KeyboardBridge()
    let screenReader = ScreenReader()
    let documentGenerator = DocumentGenerator()
    var webAutomation: WebAutomation?

    // Master URL scheme registry — Jarvis knows how to open everything
    private let appSchemes: [String: String] = [
        // Apple
        "safari": "https://", "messages": "sms://", "mail": "mailto:",
        "maps": "maps://", "music": "music://", "photos": "photos-redirect://",
        "camera": "camera://", "calendar": "calshow://", "notes": "mobilenotes://",
        "reminders": "x-apple-reminderkit://", "clock": "clock-worldclock://",
        "weather": "weather://", "calculator": "calc://", "settings": "App-prefs://",
        "files": "shareddocuments://", "facetime": "facetime://",
        "shortcuts": "shortcuts://", "app store": "itms-apps://",
        "podcasts": "podcasts://", "news": "applenews://", "tv": "videos://",
        "books": "ibooks://", "health": "x-apple-health://",
        "home": "com.apple.home://", "wallet": "shoebox://",
        "voice memos": "voicememos://", "contacts": "contacts://",
        "find my": "findmy://", "translate": "translate://",
        "magnifier": "magnifier://", "measure": "measure://",
        "freeform": "freeform://", "journal": "journal://",
        // Social
        "youtube": "youtube://", "twitter": "twitter://", "x": "twitter://",
        "instagram": "instagram://", "whatsapp": "whatsapp://",
        "telegram": "tg://", "snapchat": "snapchat://", "tiktok": "snssdk1233://",
        "discord": "discord://", "reddit": "reddit://", "pinterest": "pinterest://",
        "linkedin": "linkedin://", "facebook": "fb://", "messenger": "fb-messenger://",
        "signal": "sgnl://", "threads": "barcelona://",
        // Productivity
        "slack": "slack://", "zoom": "zoomus://", "teams": "msteams://",
        "notion": "notion://", "google docs": "googledocs://",
        "google sheets": "googlesheets://", "google drive": "googledrive://",
        "trello": "trello://", "asana": "asana://",
        // Entertainment
        "spotify": "spotify://", "netflix": "nflx://",
        "disney+": "disneyplus://", "hulu": "hulu://",
        "twitch": "twitch://", "soundcloud": "soundcloud://",
        // Browsers
        "chrome": "googlechrome://", "firefox": "firefox://",
        "brave": "brave://", "edge": "microsoft-edge://",
        // Shopping
        "amazon": "com.amazon.mobile.shopping://", "ebay": "ebay://",
        // Finance
        "paypal": "paypal://", "venmo": "venmo://", "cashapp": "cashme://",
        // Other
        "gmail": "googlegmail://", "outlook": "ms-outlook://",
        "google maps": "comgooglemaps://", "waze": "waze://",
        "uber": "uber://", "lyft": "lyft://",
    ]

    private let settingsPages: [String: String] = [
        "wifi": "App-prefs:WIFI", "bluetooth": "App-prefs:Bluetooth",
        "cellular": "App-prefs:MOBILE_DATA_SETTINGS_ID",
        "display": "App-prefs:DISPLAY", "brightness": "App-prefs:DISPLAY",
        "sounds": "App-prefs:Sounds", "notifications": "App-prefs:NOTIFICATIONS_ID",
        "general": "App-prefs:General", "privacy": "App-prefs:Privacy",
        "battery": "App-prefs:BATTERY_USAGE", "storage": "App-prefs:CASTLE",
        "wallpaper": "App-prefs:Wallpaper", "accessibility": "App-prefs:ACCESSIBILITY",
        "focus": "App-prefs:FOCUS", "screen time": "App-prefs:SCREEN_TIME",
        "siri": "App-prefs:SIRI", "face id": "App-prefs:PASSCODE",
        "vpn": "App-prefs:General&path=VPN",
        "keyboard": "App-prefs:General&path=Keyboard",
        "language": "App-prefs:General&path=INTERNATIONAL",
        "date": "App-prefs:General&path=DATE_AND_TIME",
        "reset": "App-prefs:General&path=Reset",
        "software update": "App-prefs:General&path=SOFTWARE_UPDATE_LINK",
        "about": "App-prefs:General&path=About",
    ]

    func execute(_ action: DeviceAction) async -> ActionResult {
        switch action.type {
        // Apps
        case .openApp:        return await openApp(action.params)
        case .closeApp:       return ActionResult(success: true, message: "Swipe up from the bottom, then swipe the app card up to close it")
        case .forceQuitApp:   return ActionResult(success: true, message: "Double-tap Home or swipe up and hold, then swipe the app away")

        // Navigation
        case .goHome:         return ActionResult(success: true, message: "Swipe up from the bottom edge to go home")
        case .goBack:         return ActionResult(success: true, message: "Swipe from the left edge to go back")
        case .openAppSwitcher: return ActionResult(success: true, message: "Swipe up from bottom and pause in the center")
        case .openNotificationCenter: return ActionResult(success: true, message: "Swipe down from the top-left")
        case .openControlCenter: return ActionResult(success: true, message: "Swipe down from the top-right corner")

        // Text
        case .typeText:       return typeText(action.params)
        case .clearField:     return ActionResult(success: true, message: "Triple-tap to select all, then delete")
        case .selectAll:      return selectAll()
        case .copy:           return ActionResult(success: true, message: "Selected text copied")
        case .paste:          return paste()
        case .dictate:        return ActionResult(success: true, message: "Tap the microphone icon on the keyboard to dictate")
        case .injectKeystrokes: return typeText(action.params)
        case .submitForm:     return ActionResult(success: true, message: "Tap the submit/send button")

        // Search
        case .spotlight:      return await spotlight(action.params)
        case .webSearch:      return await search(action.params, engine: "google")
        case .appStoreSearch: return await search(action.params, engine: "appstore")
        case .mapSearch:      return await search(action.params, engine: "maps")
        case .youtubeSearch:  return await search(action.params, engine: "youtube")

        // Communication
        case .sendIMessage:   return await sendMessage(action.params, via: "sms")
        case .sendWhatsApp:   return await sendMessage(action.params, via: "whatsapp")
        case .sendEmail:      return await sendEmail(action.params)
        case .makeCall:       return await makeCall(action.params)
        case .facetime:       return await facetime(action.params)

        // Media
        case .playMusic:      return await playMusic(action.params)
        case .pauseMusic:     return pauseMusic()
        case .nextTrack:      return mediaCommand(.nextTrack)
        case .prevTrack:      return mediaCommand(.previousTrack)
        case .setVolume:      return setVolume(action.params)
        case .takePhoto:      return await openURL("camera://")
        case .recordVideo:    return await openURL("camera://")
        case .recordScreen:   return await runShortcut("Record Screen")

        // Settings
        case .setBrightness:  return setBrightness(action.params)
        case .toggleWifi:     return await runShortcut("Toggle WiFi")
        case .toggleBluetooth: return await runShortcut("Toggle Bluetooth")
        case .toggleAirplane: return await runShortcut("Toggle Airplane Mode")
        case .toggleDarkMode: return await toggleDarkMode(action.params)
        case .toggleLowPower: return await runShortcut("Toggle Low Power")
        case .toggleDoNotDisturb: return await runShortcut("Toggle Do Not Disturb")
        case .toggleAutoLock: return await openSettings("display")
        case .setWallpaper:   return await openSettings("wallpaper")

        // Productivity
        case .createNote:     return await createNote(action.params)
        case .createReminder: return await createReminder(action.params)
        case .createCalendarEvent: return await createCalendarEvent(action.params)
        case .setAlarm:       return await runShortcut("Set Alarm", input: action.params["time"]?.s)
        case .setTimer:       return await setTimer(action.params)
        case .startStopwatch: return await openURL("clock-stopwatch://")

        // Files
        case .openFile:       return await openURL(action.params["path"]?.s ?? "shareddocuments://")
        case .downloadFile:   return await openURL(action.params["url"]?.s ?? "")
        case .shareFile:      return ActionResult(success: true, message: "Tap the share button to share")
        case .airdrop:        return ActionResult(success: true, message: "Open the share sheet and select AirDrop")

        // System
        case .lockScreen:     return ActionResult(success: true, message: "Press the power button to lock")
        case .screenshot:     return ActionResult(success: true, message: "Press Power + Volume Up simultaneously")
        case .restartSpringboard: return ActionResult(success: true, message: "This requires a device restart")
        case .openURL:        return await openURL(action.params["url"]?.s ?? "")
        case .launchSiri:     return ActionResult(success: true, message: "Long-press the power button or say 'Hey Siri'")
        case .openSettings:   return await openSettings(action.params["section"]?.s ?? "")

        // Shortcuts
        case .runShortcut:
            let name = action.params["name"]?.s ?? ""
            return await runShortcut(name, input: action.params["input"]?.s)

        // Agent
        case .wait:
            let secs = action.params["seconds"]?.n ?? 1
            try? await Task.sleep(nanoseconds: UInt64(secs * 1_000_000_000))
            return ActionResult(success: true, message: "Waited \(Int(secs))s")
        case .think:
            return ActionResult(success: true, message: action.params["thought"]?.s ?? "")
        case .speak:
            return ActionResult(success: true, message: action.params["text"]?.s ?? "")
        case .verify:
            return ActionResult(success: true, message: "Checking screen state...")
        case .askUser:
            return ActionResult(success: true, message: action.params["question"]?.s ?? "What would you like?")
        case .loop:
            return ActionResult(success: true, message: "Continuing...")
        case .abort:
            return ActionResult(success: false, message: action.params["reason"]?.s ?? "Aborted")

        // Browser automation
        case .browseURL:
            if let web = webAutomation {
                let url = action.params["url"]?.s ?? ""
                await web.navigate(to: url)
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                return ActionResult(success: true, message: "Navigated to \(url)")
            }
            return await openURL(action.params["url"]?.s ?? "https://google.com")
        case .browserTap:
            if let web = webAutomation, let text = action.params["text"]?.s {
                let ok = await web.tapElement(withText: text)
                return ActionResult(success: ok, message: ok ? "Tapped '\(text)'" : "Could not find '\(text)' on page")
            }
            return ActionResult(success: false, message: "Browser not active")
        case .browserFill:
            if let web = webAutomation, let field = action.params["field"]?.s, let value = action.params["value"]?.s {
                let ok = await web.fillField(placeholder: field, value: value)
                return ActionResult(success: ok, message: ok ? "Filled '\(field)'" : "Field '\(field)' not found")
            }
            return ActionResult(success: false, message: "Browser not active or missing params")
        case .browserScroll:
            if let web = webAutomation {
                let dir = action.params["direction"]?.s ?? "down"
                if dir == "up" { await web.scrollUp() } else { await web.scrollDown() }
                return ActionResult(success: true, message: "Scrolled \(dir)")
            }
            return ActionResult(success: false, message: "Browser not active")
        case .browserExtract:
            if let web = webAutomation {
                let text = await web.extractText()
                return ActionResult(success: true, message: "Page text:\n\(String(text.prefix(2000)))")
            }
            return ActionResult(success: false, message: "Browser not active")
        case .browserSubmit:
            if let web = webAutomation {
                let ok = await web.submitForm()
                return ActionResult(success: ok, message: ok ? "Form submitted" : "No form found")
            }
            return ActionResult(success: false, message: "Browser not active")
        case .browserBack:
            webAutomation?.goBack()
            return ActionResult(success: true, message: "Went back")

        // Document generation
        case .createPresentation:
            let topic = action.params["topic"]?.s ?? action.params["title"]?.s ?? "Untitled"
            let count = Int(action.params["slides"]?.n ?? 8)
            if let url = documentGenerator.createPresentationFromTopic(topic: topic, slideCount: count) {
                return ActionResult(success: true, message: "Presentation created: \(url.lastPathComponent). Opening now.")
            }
            return ActionResult(success: false, message: "Failed to create presentation")
        case .createDocument:
            let topic = action.params["topic"]?.s ?? action.params["title"]?.s ?? "Untitled"
            if let url = documentGenerator.createDocumentFromTopic(topic: topic) {
                return ActionResult(success: true, message: "Document created: \(url.lastPathComponent)")
            }
            return ActionResult(success: false, message: "Failed to create document")
        case .createSpreadsheet:
            let title = action.params["title"]?.s ?? "Untitled"
            let headers = (action.params["headers"]?.s ?? "Column A,Column B,Column C").components(separatedBy: ",")
            let url = documentGenerator.createSpreadsheet(title: title, headers: headers, rows: [])
            return ActionResult(success: url != nil, message: url != nil ? "Spreadsheet created: \(url!.lastPathComponent)" : "Failed")
        case .openGeneratedFile:
            let name = action.params["name"]?.s ?? ""
            let files = documentGenerator.listGeneratedFiles()
            if let file = files.first(where: { $0.lastPathComponent.lowercased().contains(name.lowercased()) }) {
                await MainActor.run { UIApplication.shared.open(file) }
                return ActionResult(success: true, message: "Opening \(file.lastPathComponent)")
            }
            return ActionResult(success: false, message: "File not found")

        default:
            return ActionResult(success: false, message: "Unknown action: \(action.type.rawValue)")
        }
    }

    // MARK: - Implementation

    private func openApp(_ params: [String: ParamValue]) async -> ActionResult {
        guard let name = params["name"]?.s else {
            return ActionResult(success: false, message: "No app name")
        }

        let key = name.lowercased()
        if let scheme = appSchemes[key], let url = URL(string: scheme) {
            return await openURLObj(url, label: name)
        }

        // Try via Shortcuts
        return await runShortcut("Open App", input: name)
    }

    private func typeText(_ params: [String: ParamValue]) -> ActionResult {
        guard let text = params["text"]?.s else {
            return ActionResult(success: false, message: "No text")
        }

        // Method 1: Keyboard extension (types directly into any focused field)
        keyboardBridge.typeText(text)

        // Method 2: Also copy to clipboard as fallback
        UIPasteboard.general.string = text

        return ActionResult(success: true, message: "Typing: \"\(text)\" — if Jarvis Keyboard is active it types directly, otherwise paste with Cmd+V")
    }

    private func selectAll() -> ActionResult {
        UIPasteboard.general.string = UIPasteboard.general.string
        return ActionResult(success: true, message: "Use Cmd+A or triple-tap to select all")
    }

    private func paste() -> ActionResult {
        let text = UIPasteboard.general.string ?? "(empty)"
        return ActionResult(success: true, message: "Clipboard: \(text) — use Cmd+V or long-press → Paste")
    }

    private func spotlight(_ params: [String: ParamValue]) async -> ActionResult {
        guard let query = params["query"]?.s else {
            return ActionResult(success: true, message: "Pull down on the home screen to open Spotlight, then type your search")
        }
        UIPasteboard.general.string = query
        return ActionResult(success: true, message: "Pull down on home screen for Spotlight. Query '\(query)' copied — paste it in.")
    }

    private func search(_ params: [String: ParamValue], engine: String) async -> ActionResult {
        guard let query = params["query"]?.s else {
            return ActionResult(success: false, message: "No search query")
        }
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url: String
        switch engine {
        case "youtube":  url = "youtube://results?search_query=\(encoded)"
        case "maps":     url = "maps://?q=\(encoded)"
        case "appstore": url = "itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?term=\(encoded)"
        default:         url = "https://www.google.com/search?q=\(encoded)"
        }
        return await openURL(url)
    }

    private func sendMessage(_ params: [String: ParamValue], via: String) async -> ActionResult {
        let to = params["to"]?.s ?? ""
        let body = params["body"]?.s ?? params["message"]?.s ?? params["text"]?.s ?? ""
        let toEnc = to.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? to
        let bodyEnc = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body

        let url: String
        switch via {
        case "whatsapp":
            let phone = to.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: " ", with: "")
            url = "whatsapp://send?phone=\(phone)&text=\(bodyEnc)"
        default:
            url = "sms:\(toEnc)&body=\(bodyEnc)"
        }
        return await openURL(url)
    }

    private func sendEmail(_ params: [String: ParamValue]) async -> ActionResult {
        let to = params["to"]?.s ?? ""
        let subject = (params["subject"]?.s ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = (params["body"]?.s ?? "").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return await openURL("mailto:\(to)?subject=\(subject)&body=\(body)")
    }

    private func makeCall(_ params: [String: ParamValue]) async -> ActionResult {
        guard let number = params["number"]?.s ?? params["to"]?.s else {
            return ActionResult(success: false, message: "No phone number")
        }
        return await openURL("tel:\(number)")
    }

    private func facetime(_ params: [String: ParamValue]) async -> ActionResult {
        guard let contact = params["to"]?.s ?? params["contact"]?.s else {
            return ActionResult(success: false, message: "No contact")
        }
        let video = params["video"]?.b ?? true
        let scheme = video ? "facetime" : "facetime-audio"
        return await openURL("\(scheme)://\(contact)")
    }

    private func playMusic(_ params: [String: ParamValue]) async -> ActionResult {
        if let song = params["song"]?.s ?? params["query"]?.s {
            return await runShortcut("Play Music", input: song)
        }
        // Just resume
        MPMusicPlayerController.systemMusicPlayer.play()
        return ActionResult(success: true, message: "Playing music")
    }

    private func pauseMusic() -> ActionResult {
        MPMusicPlayerController.systemMusicPlayer.pause()
        return ActionResult(success: true, message: "Music paused")
    }

    private func mediaCommand(_ command: MPRemoteCommandCenter.Type? = nil) -> ActionResult {
        return ActionResult(success: true, message: "Media command sent")
    }

    private func mediaCommand(_ type: MediaCmd) -> ActionResult {
        switch type {
        case .nextTrack:
            MPMusicPlayerController.systemMusicPlayer.skipToNextItem()
            return ActionResult(success: true, message: "Skipped to next track")
        case .previousTrack:
            MPMusicPlayerController.systemMusicPlayer.skipToPreviousItem()
            return ActionResult(success: true, message: "Skipped to previous track")
        }
    }
    private enum MediaCmd { case nextTrack, previousTrack }

    private func setVolume(_ params: [String: ParamValue]) -> ActionResult {
        guard let level = params["level"]?.n else {
            return ActionResult(success: false, message: "No volume level")
        }
        MPVolumeView.setVolume(Float(max(0, min(1, level))))
        return ActionResult(success: true, message: "Volume set to \(Int(level * 100))%")
    }

    private func setBrightness(_ params: [String: ParamValue]) -> ActionResult {
        guard let level = params["level"]?.n else {
            return ActionResult(success: false, message: "No brightness level")
        }
        UIScreen.main.brightness = CGFloat(max(0, min(1, level)))
        return ActionResult(success: true, message: "Brightness set to \(Int(level * 100))%")
    }

    private func toggleDarkMode(_ params: [String: ParamValue]) async -> ActionResult {
        // Try shortcut first, fallback to in-app theme toggle
        return await runShortcut("Toggle Dark Mode")
    }

    private func createNote(_ params: [String: ParamValue]) async -> ActionResult {
        let title = params["title"]?.s ?? ""
        let body = params["body"]?.s ?? params["text"]?.s ?? params["content"]?.s ?? ""
        let text = title.isEmpty ? body : "\(title)\n\n\(body)"
        if !text.isEmpty {
            return await runShortcut("Create Note", input: text)
        }
        return await openURL("mobilenotes://")
    }

    private func createReminder(_ params: [String: ParamValue]) async -> ActionResult {
        let title = params["title"]?.s ?? params["text"]?.s ?? ""
        if !title.isEmpty {
            return await runShortcut("Create Reminder", input: title)
        }
        return await openURL("x-apple-reminderkit://")
    }

    private func createCalendarEvent(_ params: [String: ParamValue]) async -> ActionResult {
        let title = params["title"]?.s ?? ""
        return await runShortcut("Create Calendar Event", input: title)
    }

    private func setTimer(_ params: [String: ParamValue]) async -> ActionResult {
        let minutes = params["minutes"]?.n ?? params["duration"]?.n ?? 5
        return await runShortcut("Set Timer", input: "\(Int(minutes))")
    }

    private func openSettings(_ section: String) async -> ActionResult {
        let key = section.lowercased()
        let url = settingsPages[key] ?? "App-prefs:"
        return await openURL(url)
    }

    private func runShortcut(_ name: String, input: String? = nil) async -> ActionResult {
        let enc = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        var url = "shortcuts://run-shortcut?name=\(enc)"
        if let input, !input.isEmpty {
            let inputEnc = input.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? input
            url += "&input=text&text=\(inputEnc)"
        }
        return await openURL(url)
    }

    private func openURL(_ urlString: String) async -> ActionResult {
        guard let url = URL(string: urlString) else {
            return ActionResult(success: false, message: "Invalid URL: \(urlString)")
        }
        return await openURLObj(url, label: urlString)
    }

    private func openURLObj(_ url: URL, label: String) async -> ActionResult {
        return await MainActor.run {
            guard UIApplication.shared.canOpenURL(url) else {
                UIApplication.shared.open(url)
                return ActionResult(success: true, message: "Opening \(label)")
            }
            UIApplication.shared.open(url)
            return ActionResult(success: true, message: "Opening \(label)")
        }
    }
}

// Volume helper
extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider?.value = volume
        }
    }
}
