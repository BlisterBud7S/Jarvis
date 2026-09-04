import Foundation
import SwiftUI
import UIKit
import AVFoundation

@MainActor
class JarvisBrain: ObservableObject {
    // State
    @Published var messages: [Message] = []
    @Published var isProcessing = false
    @Published var isListening = false
    @Published var currentPlan: [AgentStep] = []
    @Published var agentLoopActive = false
    @Published var statusText = "Ready"
    @Published var forcedTheme: ColorScheme? = nil
    @Published var isConnected = false

    // Config
    @AppStorage("serverURL") var serverURL = ""
    @AppStorage("apiKey") var apiKey = ""
    @AppStorage("voiceEnabled") var voiceEnabled = true
    @AppStorage("autoScreenshot") var autoScreenshot = true
    @AppStorage("jarvisVoice") var jarvisVoice = true
    @AppStorage("useOnDevice") var useOnDevice = true
    @AppStorage("hasCompletedSetup") var hasCompletedSetup = false

    // Services
    let executor = ActionExecutor()
    let screenCapture = ScreenCaptureService()
    let screenReader = ScreenReader()
    let voice = VoiceService()
    let speaker = SpeechSynthesizer()
    let memory = JarvisMemory()
    let onDeviceParser = OnDeviceParser()
    let shortcutInstaller = ShortcutInstaller()

    private var history: [HistoryTurn] = []
    private var loopTask: Task<Void, Never>?

    init() {
        messages.append(Message(
            role: .jarvis,
            content: "Good \(greeting). I'm Jarvis. I have full control of this iPad — I can open any app, write documents, send messages, browse the web, adjust every setting, and handle complex multi-step tasks autonomously. What do you need?"
        ))
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning" }
        if hour < 17 { return "afternoon" }
        return "evening"
    }

    // MARK: - Main command entry

    func processCommand(_ text: String) async {
        let command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { return }

        isProcessing = true
        messages.append(Message(role: .user, content: command))
        history.append(HistoryTurn(role: "user", content: command))
        statusText = "Thinking..."

        if useOnDevice || serverURL.isEmpty {
            // On-device mode: parse locally, execute immediately
            await executeOnDevice(command: command)
        } else {
            // Cloud mode: full agent loop
            await agentLoop(command: command, isFollowUp: false, previousResult: nil)
        }

        isProcessing = false
        statusText = "Ready"
    }

    private func executeOnDevice(command: String) async {
        let response = onDeviceParser.parse(command)

        if !response.message.isEmpty {
            messages.append(Message(role: .jarvis, content: response.message,
                actions: response.actions.map { DeviceAction(
                    type: DeviceAction.ActionType(rawValue: $0.type) ?? .think,
                    params: $0.params
                )}
            ))

            if jarvisVoice { speaker.speak(response.message) }
        }

        // Execute actions
        for actionPayload in response.actions {
            let actionType = DeviceAction.ActionType(rawValue: actionPayload.type) ?? .think
            let action = DeviceAction(type: actionType, params: actionPayload.params)
            _ = await executor.execute(action)
            if response.actions.count > 1 {
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }

        history.append(HistoryTurn(role: "assistant", content: response.message))
    }

    // MARK: - Agent loop (see → think → act → verify → repeat)

    private func agentLoop(command: String, isFollowUp: Bool, previousResult: String?) async {
        agentLoopActive = true
        var currentCommand = command
        var followUp = isFollowUp
        var prevResult = previousResult
        var iterations = 0
        let maxIterations = 10

        while agentLoopActive && iterations < maxIterations {
            iterations += 1

            // 1. See — capture current screen state + OCR read it
            var screenshot: String? = nil
            var screenText: String? = nil

            if autoScreenshot, let image = screenCapture.captureScreen() {
                screenshot = image.jpegData(compressionQuality: 0.8)?.base64EncodedString()
                statusText = "Reading screen..."
                let analysis = await screenReader.readScreen(image)
                screenText = analysis.summary
            }

            // 2. Think — send to server AI with full context
            statusText = "Planning step \(iterations)..."
            guard let response = await callServer(
                command: currentCommand,
                screenshot: screenshot,
                isFollowUp: followUp,
                previousResult: prevResult,
                screenText: screenText,
                memoryContext: memory.contextString()
            ) else {
                messages.append(Message(role: .system, content: "Lost connection to server."))
                break
            }

            // Show thinking
            if !response.thought.isEmpty {
                messages.append(Message(role: .thinking, content: response.thought, thinking: response.thought))
            }

            // Show plan
            if let plan = response.plan, !plan.isEmpty && !followUp {
                currentPlan = plan.map { AgentStep(description: $0) }
            }

            // Show response
            messages.append(Message(
                role: .jarvis,
                content: response.message,
                actions: response.actions.map { DeviceAction(
                    type: DeviceAction.ActionType(rawValue: $0.type) ?? .think,
                    params: $0.params
                )}
            ))

            // Speak response
            if jarvisVoice && !response.message.isEmpty {
                speaker.speak(response.message)
            }

            history.append(HistoryTurn(role: "assistant", content: response.message))

            // 3. Act — execute all actions
            if !response.actions.isEmpty {
                statusText = "Executing \(response.actions.count) action(s)..."
                var results: [String] = []

                for (i, actionPayload) in response.actions.enumerated() {
                    let actionType = DeviceAction.ActionType(rawValue: actionPayload.type) ?? .think
                    let action = DeviceAction(type: actionType, params: actionPayload.params)

                    // Update plan status
                    if i < currentPlan.count {
                        currentPlan[i].status = .running
                    }

                    let result = await executor.execute(action)
                    results.append("[\(actionPayload.type)] \(result.message)")

                    if i < currentPlan.count {
                        currentPlan[i].status = result.success ? .done : .failed
                    }

                    // Small delay between actions for UI to update
                    if response.actions.count > 1 {
                        try? await Task.sleep(nanoseconds: 300_000_000)
                    }
                }

                prevResult = results.joined(separator: "\n")
            }

            // 4. Check if done
            if response.isDone {
                agentLoopActive = false
                break
            }

            // 5. If AI wants to see the result, loop back
            if response.needsScreenAfter {
                statusText = "Verifying..."
                try? await Task.sleep(nanoseconds: 500_000_000)
                currentCommand = "Continue the task. Here's the current screen state."
                followUp = true
            } else {
                agentLoopActive = false
            }
        }

        if iterations >= maxIterations {
            messages.append(Message(role: .system, content: "Reached step limit. Let me know if you need me to continue."))
        }

        agentLoopActive = false
        currentPlan = []
    }

    func stopAgent() {
        agentLoopActive = false
        loopTask?.cancel()
        statusText = "Stopped"
        messages.append(Message(role: .system, content: "Stopped."))
    }

    // MARK: - Server communication

    private func callServer(command: String, screenshot: String?, isFollowUp: Bool, previousResult: String?, screenText: String? = nil, memoryContext: String? = nil) async -> AgentResponse? {
        guard !serverURL.isEmpty else { return nil }
        guard let url = URL(string: "\(serverURL)/api/agent") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 60

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        // Append screen OCR and memory to command for richer context
        var enrichedCommand = command
        if let screenText, !screenText.isEmpty {
            enrichedCommand += "\n\n[SCREEN OCR]\n\(screenText)"
        }
        if let memoryContext, !memoryContext.isEmpty {
            enrichedCommand += "\n\n\(memoryContext)"
        }

        let body = CommandRequest(
            command: enrichedCommand,
            screenshot: screenshot,
            deviceInfo: DeviceInfoPayload(
                model: UIDevice.current.model,
                os: UIDevice.current.systemVersion,
                screenW: UIScreen.main.bounds.width * UIScreen.main.scale,
                screenH: UIScreen.main.bounds.height * UIScreen.main.scale,
                battery: Int(UIDevice.current.batteryLevel * 100),
                charging: UIDevice.current.batteryState == .charging,
                time: formatter.string(from: Date())
            ),
            history: Array(history.suffix(30)),
            isFollowUp: isFollowUp,
            previousResult: previousResult
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, resp) = try await URLSession.shared.data(for: request)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(AgentResponse.self, from: data)
        } catch {
            return nil
        }
    }

    func testConnection() async -> Bool {
        guard !serverURL.isEmpty, let url = URL(string: "\(serverURL)/api/health") else { return false }
        do {
            let (_, r) = try await URLSession.shared.data(from: url)
            let ok = (r as? HTTPURLResponse)?.statusCode == 200
            isConnected = ok
            return ok
        } catch {
            isConnected = false
            return false
        }
    }

    func clearChat() {
        messages = [Message(role: .jarvis, content: "Cleared. What do you need?")]
        history = []
        currentPlan = []
    }
}
