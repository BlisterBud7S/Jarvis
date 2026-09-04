import SwiftUI

struct JarvisRootView: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                ChatView()
                    .tabItem { Label("Jarvis", systemImage: "brain.head.profile") }
                    .tag(0)

                JarvisBrowserView()
                    .tabItem { Label("Browser", systemImage: "globe") }
                    .tag(1)

                QuickActionsView()
                    .tabItem { Label("Actions", systemImage: "bolt.fill") }
                    .tag(2)

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(3)
            }
            .tint(.cyan)

            // Floating status when agent is working
            if jarvis.agentLoopActive {
                VStack {
                    AgentStatusBar()
                    Spacer()
                }
                .transition(.move(edge: .top))
            }
        }
        .animation(.easeInOut, value: jarvis.agentLoopActive)
    }
}

struct AgentStatusBar: View {
    @EnvironmentObject var jarvis: JarvisBrain

    var body: some View {
        HStack(spacing: 12) {
            PulsingOrb(size: 14)

            Text(jarvis.statusText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            Spacer()

            Button("Stop") {
                jarvis.stopAgent()
            }
            .font(.subheadline.bold())
            .foregroundStyle(.red)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.95))
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
