import SwiftUI

struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var voiceService = VoiceService()
    @FocusState private var isInputFocused: Bool

    init() {
        _viewModel = StateObject(wrappedValue: ChatViewModel(appState: AppState()))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }

                            if viewModel.isProcessing {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: viewModel.messages.count) {
                        withAnimation {
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }

                Divider()

                inputBar
            }
            .navigationTitle("Jarvis")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    connectionIndicator
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", systemImage: "trash") {
                        viewModel.clearChat()
                    }
                }
            }
        }
        .onAppear {
            voiceService.requestAuthorization()
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            Button {
                if voiceService.isListening {
                    voiceService.stopListening()
                    viewModel.inputText = voiceService.transcribedText
                } else {
                    try? voiceService.startListening()
                }
            } label: {
                Image(systemName: voiceService.isListening ? "mic.fill" : "mic")
                    .font(.title3)
                    .foregroundStyle(voiceService.isListening ? .red : .blue)
                    .frame(width: 36, height: 36)
            }
            .disabled(!voiceService.isAuthorized)

            TextField("Ask Jarvis anything...", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit {
                    Task { await viewModel.sendMessage() }
                }

            Button {
                Task { await viewModel.sendMessage() }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.inputText.isEmpty || viewModel.isProcessing ? .gray : .blue)
            }
            .disabled(viewModel.inputText.isEmpty || viewModel.isProcessing)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var connectionIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.isConnected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(appState.isConnected ? "Connected" : "Offline")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(backgroundColor)
                    .foregroundStyle(foregroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                if let actions = message.actions, !actions.isEmpty {
                    ActionsView(actions: actions)
                }

                if message.status == .executing {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Executing...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var backgroundColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return Color(.systemGray5)
        case .system: return Color(.systemGray6)
        }
    }

    private var foregroundColor: Color {
        message.role == .user ? .white : .primary
    }
}

struct ActionsView: View {
    let actions: [DeviceAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(actions) { action in
                HStack(spacing: 6) {
                    Image(systemName: iconForAction(action.type))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(describeAction(action))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    statusIcon(action.status)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func statusIcon(_ status: DeviceAction.ActionStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
        case .executing:
            ProgressView().scaleEffect(0.6)
        default:
            Image(systemName: "circle").foregroundStyle(.gray).font(.caption)
        }
    }

    private func iconForAction(_ type: DeviceAction.ActionType) -> String {
        switch type {
        case .openApp: return "app.badge"
        case .typeText: return "keyboard"
        case .tap: return "hand.tap"
        case .swipe: return "hand.draw"
        case .scroll: return "scroll"
        case .goHome: return "house"
        case .openURL: return "link"
        case .search: return "magnifyingglass"
        case .setBrightness: return "sun.max"
        case .setVolume: return "speaker.wave.3"
        case .toggleWifi: return "wifi"
        case .toggleBluetooth: return "wave.3.right"
        case .sendMessage: return "message"
        case .runShortcut: return "bolt"
        case .notification: return "bell"
        case .openSettings: return "gear"
        default: return "gear"
        }
    }

    private func describeAction(_ action: DeviceAction) -> String {
        switch action.type {
        case .openApp:
            return "Open \(action.parameters["name"]?.stringValue ?? "app")"
        case .typeText:
            return "Type: \(action.parameters["text"]?.stringValue ?? "")"
        case .openURL:
            return "Open \(action.parameters["url"]?.stringValue ?? "URL")"
        case .search:
            return "Search: \(action.parameters["query"]?.stringValue ?? "")"
        case .setBrightness:
            let level = action.parameters["level"]?.numberValue ?? 0
            return "Set brightness to \(Int(level * 100))%"
        case .runShortcut:
            return "Run '\(action.parameters["name"]?.stringValue ?? "shortcut")'"
        case .sendMessage:
            return "Message \(action.parameters["to"]?.stringValue ?? "contact")"
        default:
            return action.type.rawValue
        }
    }
}

struct TypingIndicator: View {
    @State private var dotCount = 0
    let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(dotCount % 3 == i ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Spacer()
        }
        .onReceive(timer) { _ in
            dotCount += 1
        }
    }
}
