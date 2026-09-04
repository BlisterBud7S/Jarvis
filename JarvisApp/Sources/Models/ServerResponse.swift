import Foundation

struct ServerResponse: Codable {
    let message: String
    let actions: [DeviceAction]
    let requiresScreenshot: Bool?
    let followUp: String?
}

struct CommandRequest: Codable {
    let command: String
    let screenshot: String?
    let deviceInfo: DeviceInfo
    let conversationHistory: [ConversationTurn]
}

struct ConversationTurn: Codable {
    let role: String
    let content: String
}

struct DeviceInfo: Codable {
    let model: String
    let osVersion: String
    let screenWidth: Double
    let screenHeight: Double
    let batteryLevel: Float
    let isCharging: Bool
    let currentApp: String?
}
