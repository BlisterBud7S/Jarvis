import Foundation

class JarvisMemory {

    private let storageKey = "jarvis_memory"
    private var memory: MemoryStore

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode(MemoryStore.self, from: data) {
            memory = stored
        } else {
            memory = MemoryStore()
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(memory) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    // MARK: - Contacts

    func addContact(_ name: String, phone: String? = nil, email: String? = nil) {
        let contact = Contact(name: name, phone: phone, email: email)
        memory.contacts[name.lowercased()] = contact
        save()
    }

    func findContact(_ query: String) -> Contact? {
        let lower = query.lowercased()
        return memory.contacts[lower]
            ?? memory.contacts.values.first(where: { $0.name.lowercased().contains(lower) })
    }

    // MARK: - Preferences

    func setPreference(_ key: String, value: String) {
        memory.preferences[key] = value
        save()
    }

    func getPreference(_ key: String) -> String? {
        memory.preferences[key]
    }

    // MARK: - Routines

    func addRoutine(_ name: String, actions: [String]) {
        memory.routines[name.lowercased()] = Routine(name: name, actions: actions)
        save()
    }

    func getRoutine(_ name: String) -> Routine? {
        memory.routines[name.lowercased()]
    }

    // MARK: - Notes / scratchpad

    func addNote(_ text: String) {
        memory.notes.append(NoteEntry(text: text, timestamp: Date()))
        if memory.notes.count > 100 { memory.notes.removeFirst() }
        save()
    }

    func getRecentNotes(_ count: Int = 10) -> [NoteEntry] {
        Array(memory.notes.suffix(count))
    }

    // MARK: - Context for AI

    func contextString() -> String {
        var ctx: [String] = []

        if !memory.preferences.isEmpty {
            let prefs = memory.preferences.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            ctx.append("User preferences: \(prefs)")
        }

        if !memory.contacts.isEmpty {
            let contacts = memory.contacts.values.prefix(10).map { c in
                var s = c.name
                if let p = c.phone { s += " (\(p))" }
                if let e = c.email { s += " <\(e)>" }
                return s
            }.joined(separator: ", ")
            ctx.append("Known contacts: \(contacts)")
        }

        if !memory.routines.isEmpty {
            let routines = memory.routines.values.map { $0.name }.joined(separator: ", ")
            ctx.append("Saved routines: \(routines)")
        }

        if !memory.notes.isEmpty {
            let recent = memory.notes.suffix(3).map { $0.text }.joined(separator: "; ")
            ctx.append("Recent notes: \(recent)")
        }

        return ctx.isEmpty ? "" : "[JARVIS MEMORY]\n" + ctx.joined(separator: "\n")
    }

    func clear() {
        memory = MemoryStore()
        save()
    }
}

struct MemoryStore: Codable {
    var contacts: [String: Contact] = [:]
    var preferences: [String: String] = [:]
    var routines: [String: Routine] = [:]
    var notes: [NoteEntry] = []
}

struct Contact: Codable {
    let name: String
    var phone: String?
    var email: String?
}

struct Routine: Codable {
    let name: String
    let actions: [String]
}

struct NoteEntry: Codable {
    let text: String
    let timestamp: Date
}
