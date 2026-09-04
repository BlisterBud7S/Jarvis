import Foundation

class KeyboardBridge {

    private let groupID = "group.com.jarvis.ai"

    private var defaults: UserDefaults? {
        UserDefaults(suiteName: groupID)
    }

    func typeText(_ text: String) {
        defaults?.set(text, forKey: "jarvis_type_text")
        defaults?.synchronize()
    }

    func clearField() {
        defaults?.set(true, forKey: "jarvis_clear_field")
        defaults?.synchronize()
    }

    func selectAll() {
        defaults?.set(true, forKey: "jarvis_select_all")
        defaults?.synchronize()
    }

    func deleteCharacters(_ count: Int) {
        defaults?.set(count, forKey: "jarvis_delete_chars")
        defaults?.synchronize()
    }

    func pressReturn() {
        defaults?.set(true, forKey: "jarvis_press_return")
        defaults?.synchronize()
    }

    func isTypingComplete() -> Bool {
        guard let defaults else { return true }
        let done = defaults.bool(forKey: "jarvis_typing_done")
        if done {
            defaults.set(false, forKey: "jarvis_typing_done")
            defaults.synchronize()
        }
        return done
    }

    func waitForTypingComplete(timeout: TimeInterval = 30) async -> Bool {
        let start = Date()
        while Date().timeIntervalSince(start) < timeout {
            if isTypingComplete() { return true }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return false
    }
}
