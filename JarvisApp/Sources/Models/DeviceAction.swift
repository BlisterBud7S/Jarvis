import Foundation

struct DeviceAction: Identifiable, Codable, Equatable {
    let id: UUID
    let type: ActionType
    let parameters: [String: ActionValue]
    var status: ActionStatus

    enum ActionType: String, Codable {
        case openApp
        case typeText
        case tap
        case swipe
        case scroll
        case goHome
        case goBack
        case takeScreenshot
        case setBrightness
        case setVolume
        case toggleWifi
        case toggleBluetooth
        case openURL
        case search
        case sendMessage
        case runShortcut
        case copyText
        case pasteText
        case notification
        case wait
        case openSettings
        case openControlCenter
        case lockScreen
        case launchSiri
    }

    enum ActionStatus: String, Codable {
        case pending
        case executing
        case completed
        case failed
        case skipped
    }

    init(type: ActionType, parameters: [String: ActionValue] = [:]) {
        self.id = UUID()
        self.type = type
        self.parameters = parameters
        self.status = .pending
    }
}

enum ActionValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }

    var numberValue: Double? {
        if case .number(let v) = self { return v }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let v) = self { return v }
        return nil
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Double.self) { self = .number(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { throw DecodingError.dataCorruptedError(in: container, debugMessage: "Unsupported value type") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        }
    }
}
