import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @State private var actionResult: String?

    let categories: [(String, String, [(String, String, DeviceAction)])] = [
        ("Apps", "app.badge", [
            ("Safari", "safari", DeviceAction(type: .openApp, params: ["name": .string("Safari")])),
            ("YouTube", "play.rectangle.fill", DeviceAction(type: .openApp, params: ["name": .string("YouTube")])),
            ("Messages", "message.fill", DeviceAction(type: .openApp, params: ["name": .string("Messages")])),
            ("Camera", "camera.fill", DeviceAction(type: .openApp, params: ["name": .string("Camera")])),
            ("Music", "music.note", DeviceAction(type: .openApp, params: ["name": .string("Music")])),
            ("Notes", "note.text", DeviceAction(type: .openApp, params: ["name": .string("Notes")])),
        ]),
        ("Controls", "slider.horizontal.3", [
            ("Brightness Max", "sun.max.fill", DeviceAction(type: .setBrightness, params: ["level": .number(1.0)])),
            ("Brightness Low", "sun.min.fill", DeviceAction(type: .setBrightness, params: ["level": .number(0.3)])),
            ("Dark Mode", "moon.fill", DeviceAction(type: .toggleDarkMode)),
            ("WiFi Toggle", "wifi", DeviceAction(type: .toggleWifi)),
            ("Bluetooth", "wave.3.right", DeviceAction(type: .toggleBluetooth)),
            ("Do Not Disturb", "moon.zzz.fill", DeviceAction(type: .toggleDoNotDisturb)),
        ]),
        ("Media", "play.circle.fill", [
            ("Play/Resume", "play.fill", DeviceAction(type: .playMusic)),
            ("Pause", "pause.fill", DeviceAction(type: .pauseMusic)),
            ("Next Track", "forward.fill", DeviceAction(type: .nextTrack)),
            ("Previous", "backward.fill", DeviceAction(type: .prevTrack)),
            ("Volume Up", "speaker.wave.3.fill", DeviceAction(type: .setVolume, params: ["level": .number(0.8)])),
            ("Volume Down", "speaker.wave.1.fill", DeviceAction(type: .setVolume, params: ["level": .number(0.3)])),
        ]),
        ("Productivity", "checkmark.circle.fill", [
            ("New Note", "note.text.badge.plus", DeviceAction(type: .createNote, params: ["text": .string("")])),
            ("New Reminder", "bell.badge.fill", DeviceAction(type: .createReminder, params: ["text": .string("")])),
            ("Timer 5m", "timer", DeviceAction(type: .setTimer, params: ["minutes": .number(5)])),
            ("Timer 10m", "timer", DeviceAction(type: .setTimer, params: ["minutes": .number(10)])),
            ("Spotlight", "magnifyingglass", DeviceAction(type: .spotlight, params: [:])),
            ("Settings", "gear", DeviceAction(type: .openSettings, params: [:])),
        ]),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    ForEach(categories, id: \.0) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: category.1)
                                    .foregroundStyle(.cyan)
                                Text(category.0)
                                    .font(.headline)
                            }

                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                            ], spacing: 12) {
                                ForEach(category.2, id: \.0) { item in
                                    QuickActionButton(
                                        title: item.0,
                                        icon: item.1
                                    ) {
                                        Task {
                                            let result = await jarvis.executor.execute(item.2)
                                            actionResult = result.message
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Quick Actions")
            .overlay {
                if let result = actionResult {
                    VStack {
                        Spacer()
                        Text(result)
                            .font(.subheadline)
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { actionResult = nil }
                        }
                    }
                }
            }
            .animation(.easeInOut, value: actionResult)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}
