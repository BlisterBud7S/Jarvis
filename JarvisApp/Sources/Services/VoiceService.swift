import Foundation
import Speech
import AVFoundation

@MainActor
class VoiceService: ObservableObject {
    @Published var isListening = false
    @Published var transcript = ""
    @Published var authorized = false

    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var silenceTimer: Timer?

    var onFinalTranscript: ((String) -> Void)?

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in self.authorized = (status == .authorized) }
        }
        AVAudioApplication.requestRecordPermission { granted in
            Task { @MainActor in self.authorized = self.authorized && granted }
        }
    }

    func startListening() {
        guard !isListening, authorized else { return }

        recognitionTask?.cancel()
        recognitionTask = nil
        transcript = ""

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.addsPunctuation = true

            let node = audioEngine.inputNode
            let format = node.outputFormat(forBus: 0)
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                recognitionRequest.append(buffer)
            }

            recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                Task { @MainActor in
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.resetSilenceTimer()
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        self.finishListening()
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            resetSilenceTimer()
        } catch {
            isListening = false
        }
    }

    func stopListening() {
        finishListening()
    }

    private func finishListening() {
        silenceTimer?.invalidate()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false

        let final = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !final.isEmpty {
            onFinalTranscript?(final)
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishListening() }
        }
    }
}
