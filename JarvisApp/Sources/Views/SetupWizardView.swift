import SwiftUI

struct SetupWizardView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @State private var currentStep = 0
    @State private var serverURL = ""
    @State private var apiKey = ""
    @State private var useOnDevice = true
    @State private var shortcutsInstalled = false
    @State private var keyboardEnabled = false
    @State private var permissionsGranted = false

    var body: some View {
        NavigationStack {
            TabView(selection: $currentStep) {
                // Step 0: Welcome
                welcomeStep.tag(0)
                // Step 1: Mode selection
                modeStep.tag(1)
                // Step 2: Server config (if cloud mode)
                if !useOnDevice { serverStep.tag(2) }
                // Step 3: Permissions
                permissionsStep.tag(useOnDevice ? 2 : 3)
                // Step 4: Keyboard setup
                keyboardStep.tag(useOnDevice ? 3 : 4)
                // Step 5: Shortcuts auto-install
                shortcutsStep.tag(useOnDevice ? 4 : 5)
                // Step 6: Done
                doneStep.tag(useOnDevice ? 5 : 6)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentStep)
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 140, height: 140)
                    .shadow(color: .cyan.opacity(0.5), radius: 30)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
            }

            Text("J.A.R.V.I.S.")
                .font(.system(size: 42, weight: .bold, design: .rounded))

            Text("Just A Rather Very Intelligent System")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Your personal AI that has full control\nover your iPad. Like Iron Man's Jarvis.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                withAnimation { currentStep = 1 }
            } label: {
                Text("Set Up Jarvis")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.cyan)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    private var modeStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Choose Mode", subtitle: "How should Jarvis think?")

            VStack(spacing: 16) {
                modeCard(
                    title: "On-Device (No Server)",
                    description: "Jarvis uses built-in command patterns. Works offline. Handles 90% of tasks — opening apps, typing, searching, settings, messages, media, and more.",
                    icon: "ipad",
                    selected: useOnDevice
                ) { useOnDevice = true }

                modeCard(
                    title: "Cloud AI (Claude Server)",
                    description: "Jarvis uses Claude AI for understanding. Smarter for complex tasks, natural conversation, and multi-step planning. Requires a server + API key.",
                    icon: "cloud.fill",
                    selected: !useOnDevice
                ) { useOnDevice = false }
            }
            .padding(.horizontal, 30)

            Spacer()
            nextButton { currentStep = useOnDevice ? 2 : 2 }
        }
    }

    private var serverStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Server Setup", subtitle: "Connect to your Jarvis server")

            VStack(spacing: 16) {
                TextField("Server URL (e.g. https://your-server.com)", text: $serverURL)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
                    .keyboardType(.URL)

                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                Text("Run the Jarvis server on any computer:\ncd Server && npm install && npm start")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            Spacer()
            nextButton {
                jarvis.serverURL = serverURL
                jarvis.apiKey = apiKey
                currentStep = 3
            }
        }
    }

    private var permissionsStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Permissions", subtitle: "Jarvis needs these to control your iPad")

            VStack(spacing: 12) {
                permissionRow("Microphone", icon: "mic.fill", desc: "For voice commands")
                permissionRow("Speech Recognition", icon: "waveform", desc: "To understand your voice")
                permissionRow("Notifications", icon: "bell.fill", desc: "To alert you about tasks")
            }
            .padding(.horizontal, 30)

            Button("Grant All Permissions") {
                jarvis.voice.requestPermission()
                permissionsGranted = true
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.cyan)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 30)

            Spacer()
            nextButton { currentStep += 1 }
        }
    }

    private var keyboardStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Jarvis Keyboard", subtitle: "This lets Jarvis type into any app")

            VStack(alignment: .leading, spacing: 16) {
                instructionRow(1, "Open Settings → General → Keyboard → Keyboards")
                instructionRow(2, "Tap \"Add New Keyboard...\"")
                instructionRow(3, "Select \"Jarvis\" from the list")
                instructionRow(4, "Tap \"Jarvis\" → Enable \"Allow Full Access\"")
                instructionRow(5, "When using Jarvis, switch to the Jarvis keyboard via the globe icon")
            }
            .padding(.horizontal, 30)

            Button("Open Keyboard Settings") {
                if let url = URL(string: "App-prefs:General&path=Keyboard") {
                    UIApplication.shared.open(url)
                }
            }
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.cyan)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 30)

            Spacer()
            nextButton { currentStep += 1 }
        }
    }

    private var shortcutsStep: some View {
        VStack(spacing: 24) {
            stepHeader(title: "Auto-Install Shortcuts", subtitle: "Jarvis will create all needed shortcuts")

            Text("Jarvis uses iOS Shortcuts to toggle WiFi, Bluetooth, Dark Mode, set timers, and more. Tap below to auto-create them all.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)

            Button {
                jarvis.shortcutInstaller.installAll()
                shortcutsInstalled = true
            } label: {
                HStack {
                    Image(systemName: shortcutsInstalled ? "checkmark.circle.fill" : "bolt.fill")
                    Text(shortcutsInstalled ? "Shortcuts Installed" : "Install All Shortcuts")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(shortcutsInstalled ? .green : .cyan)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 30)

            if !shortcutsInstalled {
                Text("If auto-install doesn't work, you can create them manually — see Shortcuts/README.md in the project.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            nextButton { currentStep += 1 }
        }
    }

    private var doneStep: some View {
        VStack(spacing: 30) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Jarvis is Ready")
                .font(.title.bold())

            Text("\"At your service.\"")
                .font(.title3)
                .italic()
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                jarvis.useOnDevice = useOnDevice
                jarvis.hasCompletedSetup = true
            } label: {
                Text("Activate Jarvis")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.cyan)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Helpers

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.title.bold())
                .padding(.top, 40)
            Text(subtitle)
                .foregroundStyle(.secondary)
        }
    }

    private func nextButton(action: @escaping () -> Void) -> some View {
        Button {
            withAnimation { action() }
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(.cyan)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }

    private func modeCard(title: String, description: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(selected ? .cyan : .gray)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? .cyan : .gray)
            }
            .padding()
            .background(selected ? Color.cyan.opacity(0.1) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.cyan : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func permissionRow(_ name: String, icon: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundStyle(.cyan).frame(width: 30)
            VStack(alignment: .leading) {
                Text(name).font(.subheadline.weight(.medium))
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func instructionRow(_ num: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(num)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.cyan)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}
