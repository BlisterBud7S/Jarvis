import Foundation

class OnDeviceParser {

    func parse(_ input: String) -> AgentResponse {
        let text = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Open app
        if let app = matchOpen(text) {
            return respond("Opening \(app) for you.", [
                ActionPayload(type: "openApp", params: ["name": .string(app)])
            ])
        }

        // Search
        if let (query, engine) = matchSearch(text) {
            return respond("Searching for \"\(query)\".", [
                ActionPayload(type: engine, params: ["query": .string(query)])
            ])
        }

        // Type / write text
        if let (target, content) = matchWrite(text) {
            var actions: [ActionPayload] = []
            if let target {
                actions.append(ActionPayload(type: "openApp", params: ["name": .string(target)]))
                actions.append(ActionPayload(type: "wait", params: ["seconds": .number(1.5)]))
            }
            actions.append(ActionPayload(type: "typeText", params: ["text": .string(content)]))
            let msg = target != nil ? "Writing in \(target!) for you." : "Typing that now."
            return respond(msg, actions)
        }

        // Send message
        if let (to, body) = matchMessage(text) {
            return respond("Sending message to \(to).", [
                ActionPayload(type: "sendIMessage", params: ["to": .string(to), "body": .string(body)])
            ])
        }

        // Send WhatsApp
        if let (to, body) = matchWhatsApp(text) {
            return respond("Sending WhatsApp to \(to).", [
                ActionPayload(type: "sendWhatsApp", params: ["to": .string(to), "body": .string(body)])
            ])
        }

        // Email
        if let (to, subject, body) = matchEmail(text) {
            return respond("Composing email to \(to).", [
                ActionPayload(type: "sendEmail", params: ["to": .string(to), "subject": .string(subject), "body": .string(body)])
            ])
        }

        // Call
        if let contact = matchCall(text) {
            return respond("Calling \(contact).", [
                ActionPayload(type: "makeCall", params: ["to": .string(contact)])
            ])
        }

        // FaceTime
        if let contact = matchFaceTime(text) {
            return respond("Starting FaceTime with \(contact).", [
                ActionPayload(type: "facetime", params: ["to": .string(contact), "video": .bool(true)])
            ])
        }

        // Brightness
        if let level = matchBrightness(text) {
            return respond("Brightness set to \(Int(level * 100))%.", [
                ActionPayload(type: "setBrightness", params: ["level": .number(level)])
            ])
        }

        // Volume
        if let level = matchVolume(text) {
            return respond("Volume set to \(Int(level * 100))%.", [
                ActionPayload(type: "setVolume", params: ["level": .number(level)])
            ])
        }

        // Settings toggles
        if text.contains("dark mode") || text.contains("darkmode") {
            return respond("Toggling dark mode.", [ActionPayload(type: "toggleDarkMode", params: [:])])
        }
        if text.contains("wifi") || text.contains("wi-fi") {
            return respond("Toggling WiFi.", [ActionPayload(type: "toggleWifi", params: [:])])
        }
        if text.contains("bluetooth") {
            return respond("Toggling Bluetooth.", [ActionPayload(type: "toggleBluetooth", params: [:])])
        }
        if text.contains("airplane") || text.contains("flight mode") {
            return respond("Toggling Airplane Mode.", [ActionPayload(type: "toggleAirplane", params: [:])])
        }
        if text.contains("do not disturb") || text.contains("dnd") || text.contains("don't disturb") {
            return respond("Toggling Do Not Disturb.", [ActionPayload(type: "toggleDoNotDisturb", params: [:])])
        }
        if text.contains("low power") || text.contains("battery saver") {
            return respond("Toggling Low Power Mode.", [ActionPayload(type: "toggleLowPower", params: [:])])
        }

        // Timer
        if let minutes = matchTimer(text) {
            return respond("Setting a \(Int(minutes))-minute timer.", [
                ActionPayload(type: "setTimer", params: ["minutes": .number(minutes)])
            ])
        }

        // Music
        if text.contains("play") && (text.contains("music") || text.contains("song") || text.contains("playlist")) {
            let query = extractAfter(text, words: ["play", "some", "the", "my"])
            if !query.isEmpty {
                return respond("Playing \(query).", [
                    ActionPayload(type: "playMusic", params: ["song": .string(query)])
                ])
            }
            return respond("Resuming music.", [ActionPayload(type: "playMusic", params: [:])])
        }
        if text.contains("pause") || text.contains("stop music") || text.contains("stop playing") {
            return respond("Music paused.", [ActionPayload(type: "pauseMusic", params: [:])])
        }
        if text.contains("next") && (text.contains("song") || text.contains("track")) {
            return respond("Skipping to the next track.", [ActionPayload(type: "nextTrack", params: [:])])
        }
        if text.contains("previous") || text.contains("last song") || text.contains("go back") && text.contains("song") {
            return respond("Going back to the previous track.", [ActionPayload(type: "prevTrack", params: [:])])
        }

        // Note
        if let content = matchNote(text) {
            return respond("Creating a note for you.", [
                ActionPayload(type: "createNote", params: ["text": .string(content)])
            ])
        }

        // Reminder
        if let content = matchReminder(text) {
            return respond("Reminder set.", [
                ActionPayload(type: "createReminder", params: ["text": .string(content)])
            ])
        }

        // Screenshot
        if text.contains("screenshot") || text.contains("screen shot") {
            return respond("Take a screenshot with Power + Volume Up.", [
                ActionPayload(type: "screenshot", params: [:])
            ])
        }

        // Photo
        if text.contains("take a photo") || text.contains("take photo") || text.contains("take a picture") || text.contains("open camera") {
            return respond("Opening the camera.", [
                ActionPayload(type: "takePhoto", params: [:])
            ])
        }

        // URL
        if let url = matchURL(text) {
            return respond("Opening that link.", [
                ActionPayload(type: "openURL", params: ["url": .string(url)])
            ])
        }

        // Settings
        if text.contains("settings") {
            let section = extractSettingsSection(text)
            return respond("Opening Settings\(section.isEmpty ? "" : " → \(section)").", [
                ActionPayload(type: "openSettings", params: section.isEmpty ? [:] : ["section": .string(section)])
            ])
        }

        // Go home
        if text == "go home" || text == "home" || text == "home screen" {
            return respond("Returning to the home screen.", [ActionPayload(type: "goHome", params: [:])])
        }

        // Lock
        if text.contains("lock") && (text.contains("screen") || text.contains("ipad") || text.contains("device")) {
            return respond("Press the power button to lock.", [ActionPayload(type: "lockScreen", params: [:])])
        }

        // Run shortcut
        if let name = matchShortcut(text) {
            return respond("Running the \(name) shortcut.", [
                ActionPayload(type: "runShortcut", params: ["name": .string(name)])
            ])
        }

        // Fallback — try to be helpful
        return respond(
            "I understand you want me to \"\(input)\". For complex tasks like this, connect me to the cloud AI server in Settings for full autonomous control. For now, try specific commands like \"open Safari\", \"type hello world\", \"set brightness to 50%\", or \"text Mom I'm on my way\".",
            [],
            isDone: true
        )
    }

    // MARK: - Matchers

    private func matchOpen(_ text: String) -> String? {
        let patterns = [
            "open ", "launch ", "start ", "go to ", "switch to ", "show me ",
            "bring up ", "pull up ", "fire up ", "load "
        ]
        for p in patterns {
            if text.hasPrefix(p) {
                let app = String(text.dropFirst(p.count)).trimmingCharacters(in: .whitespaces)
                if !app.isEmpty && !app.contains(" and ") { return app.capitalized }
            }
        }
        return nil
    }

    private func matchSearch(_ text: String) -> (String, String)? {
        if text.hasPrefix("search youtube for ") || text.hasPrefix("youtube search ") || text.hasPrefix("search on youtube ") {
            let query = text.replacingOccurrences(of: "search youtube for ", with: "")
                .replacingOccurrences(of: "youtube search ", with: "")
                .replacingOccurrences(of: "search on youtube ", with: "")
            return (query, "youtubeSearch")
        }
        if text.hasPrefix("search for ") || text.hasPrefix("google ") || text.hasPrefix("search ") || text.hasPrefix("look up ") {
            let query = text.replacingOccurrences(of: "search for ", with: "")
                .replacingOccurrences(of: "google ", with: "")
                .replacingOccurrences(of: "search ", with: "")
                .replacingOccurrences(of: "look up ", with: "")
            return (query, "webSearch")
        }
        if text.hasPrefix("find on map ") || text.hasPrefix("map ") || text.hasPrefix("directions to ") || text.hasPrefix("navigate to ") {
            let query = text.replacingOccurrences(of: "find on map ", with: "")
                .replacingOccurrences(of: "map ", with: "")
                .replacingOccurrences(of: "directions to ", with: "")
                .replacingOccurrences(of: "navigate to ", with: "")
            return (query, "mapSearch")
        }
        return nil
    }

    private func matchWrite(_ text: String) -> (String?, String)? {
        // "write X in Notes" / "type X in Notes"
        let writePatterns = [
            ("write ", " in "), ("type ", " in "), ("write ", " on "),
            ("put ", " in "), ("enter ", " in "),
        ]
        for (prefix, separator) in writePatterns {
            if text.hasPrefix(prefix), let range = text.range(of: separator, options: .backwards) {
                let content = String(text[text.index(text.startIndex, offsetBy: prefix.count)..<range.lowerBound])
                let target = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !content.isEmpty { return (target.capitalized, content) }
            }
        }

        // "open Notes and write X"
        if text.contains(" and write ") || text.contains(" and type ") {
            let parts = text.components(separatedBy: " and write ")
                .count > 1 ? text.components(separatedBy: " and write ") :
                text.components(separatedBy: " and type ")
            if parts.count == 2 {
                let app = parts[0].replacingOccurrences(of: "open ", with: "").trimmingCharacters(in: .whitespaces)
                return (app.capitalized, parts[1].trimmingCharacters(in: .whitespaces))
            }
        }

        // Just "type X" / "write X"
        if text.hasPrefix("type ") {
            return (nil, String(text.dropFirst(5)))
        }
        if text.hasPrefix("write ") && !text.contains(" in ") {
            return (nil, String(text.dropFirst(6)))
        }

        return nil
    }

    private func matchMessage(_ text: String) -> (String, String)? {
        // "text/message Mom saying I'll be late"
        let patterns = ["text ", "message ", "send a text to ", "send a message to ", "imessage ", "sms "]
        for p in patterns {
            if text.hasPrefix(p) {
                let rest = String(text.dropFirst(p.count))
                if let sayRange = rest.range(of: " saying ") ?? rest.range(of: " that ") ?? rest.range(of: " with ") {
                    let to = String(rest[..<sayRange.lowerBound])
                    let body = String(rest[sayRange.upperBound...])
                    return (to.capitalized, body)
                }
                // Just recipient, no body
                return (rest.capitalized, "")
            }
        }
        return nil
    }

    private func matchWhatsApp(_ text: String) -> (String, String)? {
        if text.hasPrefix("whatsapp ") {
            let rest = String(text.dropFirst(9))
            if let sayRange = rest.range(of: " saying ") ?? rest.range(of: " that ") {
                let to = String(rest[..<sayRange.lowerBound])
                let body = String(rest[sayRange.upperBound...])
                return (to, body)
            }
            return (rest, "")
        }
        return nil
    }

    private func matchEmail(_ text: String) -> (String, String, String)? {
        if text.contains("email") || text.contains("e-mail") {
            let rest = text.replacingOccurrences(of: "send an email to ", with: "")
                .replacingOccurrences(of: "send email to ", with: "")
                .replacingOccurrences(of: "email ", with: "")

            if let aboutRange = rest.range(of: " about ") ?? rest.range(of: " regarding ") {
                let to = String(rest[..<aboutRange.lowerBound])
                let subject = String(rest[aboutRange.upperBound...])
                return (to, subject, "")
            }
            return (rest, "", "")
        }
        return nil
    }

    private func matchCall(_ text: String) -> String? {
        let patterns = ["call ", "phone ", "dial ", "ring "]
        for p in patterns {
            if text.hasPrefix(p) {
                return String(text.dropFirst(p.count)).capitalized
            }
        }
        return nil
    }

    private func matchFaceTime(_ text: String) -> String? {
        if text.hasPrefix("facetime ") { return String(text.dropFirst(9)).capitalized }
        if text.hasPrefix("video call ") { return String(text.dropFirst(11)).capitalized }
        return nil
    }

    private func matchBrightness(_ text: String) -> Double? {
        if text.contains("brightness") {
            if text.contains("max") || text.contains("full") || text.contains("100") { return 1.0 }
            if text.contains("min") || text.contains("lowest") { return 0.05 }
            if text.contains("half") || text.contains("50") { return 0.5 }
            if let pct = extractPercentage(text) { return pct }
        }
        return nil
    }

    private func matchVolume(_ text: String) -> Double? {
        if text.contains("volume") {
            if text.contains("max") || text.contains("full") || text.contains("100") { return 1.0 }
            if text.contains("mute") || text.contains("silent") || text.contains("off") { return 0.0 }
            if text.contains("half") || text.contains("50") { return 0.5 }
            if text.contains("up") { return 0.8 }
            if text.contains("down") || text.contains("low") { return 0.3 }
            if let pct = extractPercentage(text) { return pct }
        }
        return nil
    }

    private func matchTimer(_ text: String) -> Double? {
        if text.contains("timer") || text.contains("countdown") {
            if let num = extractNumber(text) { return num }
            if text.contains("5 min") { return 5 }
            if text.contains("10 min") { return 10 }
            if text.contains("15 min") { return 15 }
            if text.contains("30 min") || text.contains("half hour") { return 30 }
            if text.contains("1 hour") || text.contains("one hour") { return 60 }
        }
        return nil
    }

    private func matchNote(_ text: String) -> String? {
        let patterns = ["create a note ", "make a note ", "note: ", "new note "]
        for p in patterns {
            if text.hasPrefix(p) { return String(text.dropFirst(p.count)) }
        }
        if text.hasPrefix("note ") && text.count > 10 { return String(text.dropFirst(5)) }
        return nil
    }

    private func matchReminder(_ text: String) -> String? {
        let patterns = ["remind me to ", "reminder to ", "create a reminder ", "set a reminder ", "remember to "]
        for p in patterns {
            if text.hasPrefix(p) { return String(text.dropFirst(p.count)) }
        }
        return nil
    }

    private func matchURL(_ text: String) -> String? {
        if text.contains("http://") || text.contains("https://") || text.contains("www.") {
            let words = text.components(separatedBy: " ")
            return words.first(where: { $0.contains("http") || $0.contains("www.") })
        }
        if text.hasPrefix("go to ") && text.contains(".") {
            let domain = String(text.dropFirst(6))
            if !domain.contains(" ") {
                return domain.hasPrefix("http") ? domain : "https://\(domain)"
            }
        }
        return nil
    }

    private func matchShortcut(_ text: String) -> String? {
        let patterns = ["run shortcut ", "run the shortcut ", "run my ", "execute shortcut "]
        for p in patterns {
            if text.hasPrefix(p) {
                return String(text.dropFirst(p.count))
                    .replacingOccurrences(of: " shortcut", with: "")
                    .trimmingCharacters(in: .whitespaces)
                    .capitalized
            }
        }
        return nil
    }

    private func extractSettingsSection(_ text: String) -> String {
        let sections = ["wifi", "bluetooth", "display", "brightness", "sounds", "notifications",
                       "general", "privacy", "battery", "storage", "wallpaper", "accessibility",
                       "siri", "cellular", "vpn", "keyboard"]
        return sections.first(where: { text.contains($0) }) ?? ""
    }

    // MARK: - Helpers

    private func extractPercentage(_ text: String) -> Double? {
        let pattern = #"(\d+)\s*%"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            let numStr = text[match].replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
            if let num = Double(numStr) { return num / 100 }
        }
        return nil
    }

    private func extractNumber(_ text: String) -> Double? {
        let pattern = #"(\d+)"#
        if let match = text.range(of: pattern, options: .regularExpression) {
            return Double(text[match])
        }
        return nil
    }

    private func extractAfter(_ text: String, words: [String]) -> String {
        var result = text
        for w in words {
            result = result.replacingOccurrences(of: w + " ", with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private func respond(_ message: String, _ actions: [ActionPayload], isDone: Bool = true) -> AgentResponse {
        AgentResponse(
            thought: "",
            message: message,
            actions: actions,
            needsScreenAfter: false,
            isDone: isDone,
            plan: nil
        )
    }
}
