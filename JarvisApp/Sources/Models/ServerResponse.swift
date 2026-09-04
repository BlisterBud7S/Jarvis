import Foundation

struct AgentResponse: Codable {
    let thought: String
    let message: String
    let actions: [ActionPayload]
    let needsScreenAfter: Bool
    let isDone: Bool
    let plan: [String]?
}

struct ActionPayload: Codable {
    let type: String
    let params: [String: ParamValue]
}

struct CommandRequest: Codable {
    let command: String
    let screenshot: String?
    let deviceInfo: DeviceInfoPayload
    let history: [HistoryTurn]
    let isFollowUp: Bool
    let previousResult: String?
}

struct HistoryTurn: Codable {
    let role: String
    let content: String
}

struct DeviceInfoPayload: Codable {
    let model: String
    let os: String
    let screenW: Double
    let screenH: Double
    let battery: Int
    let charging: Bool
    let time: String
}
