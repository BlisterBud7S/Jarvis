import Foundation

struct Message: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    var actions: [DeviceAction]?
    var thinking: String?

    enum Role: String { case user, jarvis, system, thinking }

    static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
}

struct AgentStep: Identifiable {
    let id = UUID()
    let description: String
    var status: StepStatus = .pending

    enum StepStatus { case pending, running, done, failed }
}
