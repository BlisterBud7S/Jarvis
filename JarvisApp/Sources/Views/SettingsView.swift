import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @State private var testing = false
    @State private var testResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server URL (e.g. https://your-server.com)", text: $jarvis.serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .textContentType(.URL)

                    SecureField("API Key", text: $jarvis.apiKey)

                    Button {
                        testing = true
                        testResult = nil
                        Task {
                            let ok = await jarvis.testConnection()
                            testResult = ok ? "Connected" : "Failed"
                            testing = false
                        }
                    } label: {
                        HStack {
                            Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if testing { ProgressView() }
                            else if let r = testResult {
                                Text(r).font(.caption).foregroundStyle(r == "Connected" ? .green : .red)
                            }
                        }
                    }
                    .disabled(jarvis.serverURL.isEmpty)
                }

                Section("Behavior") {
                    Toggle("Voice Input", isOn: $jarvis.voiceEnabled)
                    Toggle("Jarvis Speaks Responses", isOn: $jarvis.jarvisVoice)
                    Toggle("Auto-capture Screen for Context", isOn: $jarvis.autoScreenshot)
                }

                Section("Capabilities") {
                    capRow("Open any app", "app.badge", true)
                    capRow("Type & paste text", "keyboard", true)
                    capRow("Web search (Google, YouTube, Maps)", "magnifyingglass", true)
                    capRow("Send messages & emails", "message.fill", true)
                    capRow("Make calls & FaceTime", "phone.fill", true)
                    capRow("Control music playback", "music.note", true)
                    capRow("Adjust brightness & volume", "sun.max.fill", true)
                    capRow("Create notes & reminders", "note.text", true)
                    capRow("Set timers & alarms", "timer", true)
                    capRow("Toggle WiFi, Bluetooth, etc.", "wifi", true)
                    capRow("Run iOS Shortcuts", "bolt.fill", true)
                    capRow("Multi-step autonomous tasks", "brain.head.profile", true)
                    capRow("Voice commands", "mic.fill", true)
                    capRow("Screen analysis (AI Vision)", "eye.fill", true)
                }

                Section("Shortcuts Setup") {
                    Text("For full control, create the required Shortcuts in the iOS Shortcuts app. See the Shortcuts folder in the repo for instructions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(destination: URL(string: "shortcuts://")!) {
                        Label("Open Shortcuts App", systemImage: "arrow.up.forward.app")
                    }
                }

                Section("Info") {
                    LabeledContent("Version", value: "2.0.0")
                    LabeledContent("Device", value: UIDevice.current.model)
                    LabeledContent("iPadOS", value: UIDevice.current.systemVersion)
                    LabeledContent("Agent Model", value: "Claude")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func capRow(_ name: String, _ icon: String, _ enabled: Bool) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.cyan)
                .frame(width: 24)
            Text(name)
                .font(.subheadline)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}
