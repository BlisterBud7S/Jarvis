import SwiftUI

struct VoiceInputSheet: View {
    @EnvironmentObject var jarvis: JarvisBrain
    @Environment(\.dismiss) var dismiss
    @State private var isListening = false
    @State private var transcript = ""
    @State private var orbScale: CGFloat = 1.0
    var onSubmit: (String) -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("Speak to Jarvis")
                .font(.title2.bold())
                .padding(.top, 30)

            Spacer()

            // Giant pulsing orb
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 200, height: 200)
                    .scaleEffect(isListening ? 1.3 : 1)

                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 160, height: 160)
                    .scaleEffect(isListening ? 1.2 : 1)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(orbScale)
                    .shadow(color: .cyan.opacity(0.5), radius: isListening ? 20 : 5)

                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }
            .onTapGesture {
                if isListening {
                    stopListening()
                } else {
                    startListening()
                }
            }
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isListening)

            // Transcript
            Text(transcript.isEmpty ? (isListening ? "Listening..." : "Tap to speak") : transcript)
                .font(.body)
                .foregroundStyle(transcript.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .frame(minHeight: 60)

            Spacer()

            // Send button
            if !transcript.isEmpty {
                Button {
                    onSubmit(transcript)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Send to Jarvis")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.cyan)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 30)
            }

            Button("Cancel") { dismiss() }
                .foregroundStyle(.secondary)
                .padding(.bottom, 20)
        }
        .onAppear { startListening() }
        .onDisappear { jarvis.voice.stopListening() }
    }

    private func startListening() {
        isListening = true
        orbScale = 1.1
        jarvis.voice.onFinalTranscript = { text in
            transcript = text
            isListening = false
            orbScale = 1.0
        }
        jarvis.voice.startListening()
    }

    private func stopListening() {
        jarvis.voice.stopListening()
        isListening = false
        orbScale = 1.0
    }
}
