import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var isTestingConnection = false
    @State private var connectionResult: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server Configuration") {
                    TextField("Server URL", text: $appState.serverURL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .textContentType(.URL)

                    SecureField("API Key", text: $appState.apiKey)

                    Button {
                        testConnection()
                    } label: {
                        HStack {
                            Text("Test Connection")
                            Spacer()
                            if isTestingConnection {
                                ProgressView()
                            } else if let result = connectionResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundStyle(result == "Connected" ? .green : .red)
                            }
                        }
                    }
                    .disabled(appState.serverURL.isEmpty || isTestingConnection)
                }

                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Device", value: UIDevice.current.model)
                    LabeledContent("iOS", value: UIDevice.current.systemVersion)
                }

                Section("Required Shortcuts") {
                    Text("Import the Jarvis shortcuts from the Shortcuts folder to enable full device control. These extend what the app can do beyond its sandbox.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link("Open Shortcuts App", destination: URL(string: "shortcuts://")!)
                }

                Section("Permissions") {
                    Text("Jarvis needs these permissions to work:")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label("Microphone (for voice commands)", systemImage: "mic")
                    Label("Speech Recognition", systemImage: "waveform")
                    Label("Notifications", systemImage: "bell")
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func testConnection() {
        isTestingConnection = true
        connectionResult = nil
        Task {
            let connected = await appState.jarvisService.checkConnection()
            isTestingConnection = false
            connectionResult = connected ? "Connected" : "Failed"
            appState.isConnected = connected
        }
    }
}
