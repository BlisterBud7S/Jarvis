import SwiftUI

struct ChatView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @State private var inputText = ""
    @State private var showVoice = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(jarvis.messages) { msg in
                                MessageRow(message: msg)
                                    .id(msg.id)
                            }

                            // Live plan
                            if !jarvis.currentPlan.isEmpty {
                                PlanView(steps: jarvis.currentPlan)
                                    .id("plan")
                            }

                            if jarvis.isProcessing {
                                ThinkingView()
                                    .id("thinking")
                            }
                        }
                        .padding()
                    }
                    .onChange(of: jarvis.messages.count) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(jarvis.messages.last?.id ?? "thinking", anchor: .bottom)
                        }
                    }
                    .onChange(of: jarvis.currentPlan.count) {
                        withAnimation { proxy.scrollTo("plan", anchor: .bottom) }
                    }
                }

                Divider()
                inputBar
            }
            .navigationTitle("Jarvis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(jarvis.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        Text(jarvis.isConnected ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", systemImage: "trash") {
                        jarvis.clearChat()
                    }
                }
            }
            .sheet(isPresented: $showVoice) {
                VoiceInputSheet(onSubmit: { text in
                    inputText = text
                    sendMessage()
                })
                .environmentObject(jarvis)
                .presentationDetents([.medium])
            }
        }
        .task {
            jarvis.isConnected = await jarvis.testConnection()
        }
    }

    private var inputBar: some View {
        HStack(spacing: 12) {
            // Voice button
            Button {
                showVoice = true
            } label: {
                Image(systemName: "mic.fill")
                    .font(.title3)
                    .foregroundStyle(.cyan)
                    .frame(width: 40, height: 40)
                    .background(Color.cyan.opacity(0.15))
                    .clipShape(Circle())
            }

            // Text input
            TextField("Tell Jarvis what to do...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($focused)
                .onSubmit { sendMessage() }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

            // Send
            Button { sendMessage() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? .cyan : .gray)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !jarvis.isProcessing
    }

    private func sendMessage() {
        let text = inputText
        inputText = ""
        focused = false
        Task { await jarvis.processCommand(text) }
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .user {
                Spacer(minLength: 60)
            } else if message.role != .thinking {
                avatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                if message.role == .thinking {
                    thinkingBubble
                } else {
                    textBubble
                }

                if let actions = message.actions, !actions.isEmpty {
                    ActionListView(actions: actions)
                }
            }

            if message.role != .user && message.role != .thinking {
                Spacer(minLength: 60)
            }
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(message.role == .jarvis
                    ? LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [.gray.opacity(0.3)], startPoint: .top, endPoint: .bottom)
                )
                .frame(width: 32, height: 32)

            Image(systemName: message.role == .jarvis ? "brain.head.profile" : "info.circle")
                .font(.caption)
                .foregroundStyle(.white)
        }
    }

    private var textBubble: some View {
        Text(message.content)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleColor)
            .foregroundStyle(message.role == .user ? .white : .primary)
            .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var thinkingBubble: some View {
        HStack(spacing: 8) {
            Image(systemName: "brain")
                .foregroundStyle(.purple)
                .font(.caption)
            Text(message.content)
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bubbleColor: Color {
        switch message.role {
        case .user: return .cyan
        case .jarvis: return Color(.systemGray5)
        case .system: return Color(.systemGray6)
        case .thinking: return Color.purple.opacity(0.1)
        }
    }
}

// MARK: - Action List

struct ActionListView: View {
    let actions: [DeviceAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(actions) { action in
                HStack(spacing: 8) {
                    Image(systemName: action.type.icon)
                        .font(.caption)
                        .foregroundStyle(.cyan)
                        .frame(width: 16)

                    Text(action.type.displayName)
                        .font(.caption.weight(.medium))

                    if let detail = action.params.values.first?.description {
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()
                    statusDot(action.status)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func statusDot(_ status: DeviceAction.Status) -> some View {
        switch status {
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.caption2)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption2)
        case .running: ProgressView().scaleEffect(0.5)
        default: Circle().fill(.gray.opacity(0.3)).frame(width: 8, height: 8)
        }
    }
}

// MARK: - Plan View

struct PlanView: View {
    let steps: [AgentStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.cyan)
                Text("Plan")
                    .font(.subheadline.bold())
            }

            ForEach(Array(steps.enumerated()), id: \.element.id) { i, step in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(stepColor(step.status))
                            .frame(width: 22, height: 22)
                        if step.status == .running {
                            ProgressView().scaleEffect(0.5)
                        } else {
                            Text("\(i + 1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        }
                    }

                    Text(step.description)
                        .font(.caption)
                        .foregroundStyle(step.status == .done ? .secondary : .primary)
                        .strikethrough(step.status == .done)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cyan.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func stepColor(_ s: AgentStep.StepStatus) -> Color {
        switch s {
        case .pending: return .gray
        case .running: return .cyan
        case .done: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Thinking animation

struct ThinkingView: View {
    @State private var phase = 0.0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase.truncatingRemainder(dividingBy: 3) == Double(i) ? 1.3 : 0.7)
                        .opacity(phase.truncatingRemainder(dividingBy: 3) == Double(i) ? 1 : 0.4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray5))
            .clipShape(Capsule())

            Spacer()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever()) { phase = 3 }
        }
    }
}

// MARK: - Pulsing Orb

struct PulsingOrb: View {
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.cyan.opacity(0.3))
                .frame(width: size * 1.8, height: size * 1.8)
                .scaleEffect(pulse ? 1.3 : 1)
                .opacity(pulse ? 0 : 0.5)

            Circle()
                .fill(.cyan)
                .frame(width: size, height: size)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }
}
