import Foundation
import UIKit

@MainActor
class JarvisService: ObservableObject {
    private weak var appState: AppState?
    private let session = URLSession.shared
    private var conversationHistory: [ConversationTurn] = []

    init(appState: AppState) {
        self.appState = appState
    }

    func sendCommand(_ command: String, screenshot: UIImage? = nil) async throws -> ServerResponse {
        guard let appState, !appState.serverURL.isEmpty else {
            throw JarvisError.notConfigured
        }

        let url = URL(string: "\(appState.serverURL)/api/command")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(appState.apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let screenshotBase64 = screenshot?.jpegData(compressionQuality: 0.7)?.base64EncodedString()

        let deviceInfo = DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            screenWidth: UIScreen.main.bounds.width,
            screenHeight: UIScreen.main.bounds.height,
            batteryLevel: UIDevice.current.batteryLevel,
            isCharging: UIDevice.current.batteryState == .charging,
            currentApp: nil
        )

        conversationHistory.append(ConversationTurn(role: "user", content: command))

        let body = CommandRequest(
            command: command,
            screenshot: screenshotBase64,
            deviceInfo: deviceInfo,
            conversationHistory: Array(conversationHistory.suffix(20))
        )

        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw JarvisError.serverError
        }

        let serverResponse = try JSONDecoder().decode(ServerResponse.self, from: data)
        conversationHistory.append(ConversationTurn(role: "assistant", content: serverResponse.message))

        return serverResponse
    }

    func checkConnection() async -> Bool {
        guard let appState, !appState.serverURL.isEmpty else { return false }
        guard let url = URL(string: "\(appState.serverURL)/api/health") else { return false }

        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    func clearHistory() {
        conversationHistory = []
    }
}

enum JarvisError: LocalizedError {
    case notConfigured
    case serverError
    case actionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Server URL not configured. Go to Settings."
        case .serverError: return "Server returned an error."
        case .actionFailed(let reason): return "Action failed: \(reason)"
        }
    }
}
