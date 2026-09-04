import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var inputText = ""
    @Published var isProcessing = false
    @Published var errorMessage: String?

    private let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        messages.append(Message(
            role: .system,
            content: "Hi! I'm Jarvis, your AI iPad assistant. Tell me what you'd like me to do — open apps, search the web, adjust settings, send messages, and more."
        ))
    }

    func sendMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isProcessing else { return }

        inputText = ""
        isProcessing = true
        errorMessage = nil

        let userMessage = Message(role: .user, content: text)
        messages.append(userMessage)

        do {
            let screenshot = appState.screenCaptureService.captureScreen()
            let response = try await appState.jarvisService.sendCommand(text, screenshot: screenshot)

            var assistantMessage = Message(
                role: .assistant,
                content: response.message,
                actions: response.actions,
                status: response.actions.isEmpty ? .completed : .executing
            )
            messages.append(assistantMessage)

            if !response.actions.isEmpty {
                let results = await appState.automationEngine.executeAll(actions: response.actions)
                let allSucceeded = results.allSatisfy { $0.success }

                if let lastIndex = messages.lastIndex(where: { $0.id == assistantMessage.id }) {
                    messages[lastIndex].status = allSucceeded ? .completed : .failed
                }

                let resultSummary = results.map { $0.message }.joined(separator: "\n")
                if !allSucceeded {
                    messages.append(Message(
                        role: .system,
                        content: "Some actions encountered issues:\n\(resultSummary)"
                    ))
                }
            }

            if let followUp = response.followUp, !followUp.isEmpty {
                messages.append(Message(role: .system, content: followUp))
            }

        } catch {
            errorMessage = error.localizedDescription
            messages.append(Message(
                role: .system,
                content: "Error: \(error.localizedDescription)",
                status: .failed
            ))
        }

        isProcessing = false
    }

    func clearChat() {
        messages = [Message(
            role: .system,
            content: "Chat cleared. What would you like me to do?"
        )]
        appState.jarvisService.clearHistory()
    }
}
