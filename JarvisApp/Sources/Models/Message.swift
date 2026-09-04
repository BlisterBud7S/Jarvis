import Foundation

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    var actions: [DeviceAction]?
    var status: MessageStatus

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    enum MessageStatus: String, Codable {
        case sending
        case sent
        case executing
        case completed
        case failed
    }

    init(role: Role, content: String, actions: [DeviceAction]? = nil, status: MessageStatus = .sent) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
        self.actions = actions
        self.status = status
    }
}
