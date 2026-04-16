import Foundation
import Combine
import AVFoundation
import UIKit

@MainActor
final class InterpreterViewModel: ObservableObject {
    // MARK: - Published State

    @Published var hasAPIKey: Bool = false
    @Published var userLanguage: Language = .english
    @Published var foreignLanguage: Language = .spanish
    @Published var selectedVoice: Voice = .kore
    @Published var showOnboarding: Bool = false

    let sessionState = SessionState()
    let audioSessionManager = AudioSessionManager()

    // MARK: - Private Services

    private let captureService = AudioCaptureService()
    private let playbackService = AudioPlaybackService()
    private let apiService = GeminiLiveService()

    private var currentTranscript = ""
    private var inputAudioBytesSent: Int = 0
    private var outputAudioBytesReceived: Int = 0
    private var lastReconnectTime: Date = .distantPast

    // MARK: - Init

    init() {
        hasAPIKey = KeychainService.hasAPIKey

        if !hasAPIKey {
            showOnboarding = true
        }

        loadPreferences()
        setupCallbacks()
    }

    // MARK: - API Key Management

    func saveAPIKey(_ key: String) {
        do {
            try KeychainService.save(apiKey: key)
            hasAPIKey = true
            showOnboarding = false
        } catch {
            sessionState.connectionStatus = .error("Failed to save API key: \(error.localizedDescription)")
        }
    }

    func deleteAPIKey() {
        KeychainService.delete()
        hasAPIKey = false
    }

    // MARK: - Session Lifecycle

    func startListening() {
        guard let apiKey = KeychainService.retrieve() else {
            sessionState.connectionStatus = .error("No API key found. Please add your Google AI API key.")
            showOnboarding = true
            return
        }

        // Configure audio session
        do {
            try audioSessionManager.configureSession()
        } catch {
            sessionState.connectionStatus = .error("Audio session error: \(error.localizedDescription)")
            return
        }

        // Reset state
        sessionState.startSession()
        inputAudioBytesSent = 0
        outputAudioBytesReceived = 0
        currentTranscript = ""
        lastReconnectTime = Date()

        // Build setup message
        let setup = buildSetupMessage()

        // Connect to API
        apiService.connect(apiKey: apiKey, setupMessage: setup)

        // Start audio capture
        do {
            try captureService.startCapture()
        } catch {
            sessionState.connectionStatus = .error("Microphone error: \(error.localizedDescription)")
            return
        }

        // Start playback
        do {
            try playbackService.setup()
        } catch {
            sessionState.connectionStatus = .error("Audio playback error: \(error.localizedDescription)")
            return
        }

        // Keep screen on
        UIApplication.shared.isIdleTimerDisabled = true
    }

    func stopListening() {
        captureService.stopCapture()
        playbackService.stop()
        apiService.disconnect()
        sessionState.stopSession()
        audioSessionManager.deactivateSession()

        // Allow screen to sleep
        UIApplication.shared.isIdleTimerDisabled = false
    }

    // MARK: - Preferences

    func savePreferences() {
        UserDefaults.standard.set(userLanguage.rawValue, forKey: "voxbridge.userLanguage")
        UserDefaults.standard.set(foreignLanguage.rawValue, forKey: "voxbridge.foreignLanguage")
        UserDefaults.standard.set(selectedVoice.rawValue, forKey: "voxbridge.voice")
    }

    // MARK: - Private

    private func loadPreferences() {
        if let raw = UserDefaults.standard.string(forKey: "voxbridge.userLanguage"),
           let lang = Language(rawValue: raw) {
            userLanguage = lang
        }
        if let raw = UserDefaults.standard.string(forKey: "voxbridge.foreignLanguage"),
           let lang = Language(rawValue: raw) {
            foreignLanguage = lang
        }
        if let raw = UserDefaults.standard.string(forKey: "voxbridge.voice"),
           let voice = Voice(rawValue: raw) {
            selectedVoice = voice
        }
    }

    private func setupCallbacks() {
        // Audio capture → WebSocket
        captureService.onAudioCaptured = { [weak self] data in
            guard let self = self else { return }
            self.apiService.sendAudio(data)

            // Track input audio duration (16kHz PCM16 = 2 bytes per sample)
            let seconds = Double(data.count) / (2.0 * Constants.inputSampleRate)
            Task { @MainActor [weak self] in
                self?.sessionState.addInputAudioDuration(seconds)
                self?.inputAudioBytesSent += data.count
            }
        }

        captureService.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.sessionState.inputAudioLevel = level
                self?.checkSessionTimeout()
            }
        }

        playbackService.onOutputLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.sessionState.outputAudioLevel = level
            }
        }

        // API delegate
        apiService.delegate = self

        // Route change handling
        audioSessionManager.onHeadphonesDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                self?.stopListening()
                self?.sessionState.connectionStatus = .error("Headphones disconnected. Session paused.")
            }
        }
    }

    private func buildSetupMessage() -> GeminiSetupMessage {
        let instructions = Constants.systemPrompt(
            userLanguage: userLanguage.displayName,
            foreignLanguage: foreignLanguage.displayName
        )

        return GeminiSetupMessage(
            setup: GeminiSetupMessage.SetupConfig(
                model: Constants.geminiModel,
                generationConfig: GeminiSetupMessage.GenerationConfig(
                    responseModalities: ["AUDIO"],
                    speechConfig: GeminiSetupMessage.SpeechConfig(
                        voiceConfig: GeminiSetupMessage.VoiceConfig(
                            prebuiltVoiceConfig: GeminiSetupMessage.PrebuiltVoiceConfig(
                                voiceName: selectedVoice.geminiVoiceName
                            )
                        )
                    )
                ),
                systemInstruction: GeminiSetupMessage.SystemInstruction(
                    parts: [GeminiSetupMessage.Part(text: instructions)]
                ),
                realtimeInputConfig: GeminiSetupMessage.RealtimeInputConfig(
                    automaticActivityDetection: GeminiSetupMessage.AutomaticActivityDetection(disabled: false),
                    inputAudioTranscription: GeminiSetupMessage.EmptyConfig(),
                    outputAudioTranscription: GeminiSetupMessage.EmptyConfig()
                ),
                contextWindowCompression: GeminiSetupMessage.ContextWindowCompression(
                    slidingWindow: GeminiSetupMessage.SlidingWindow(
                        targetTokens: Constants.contextWindowTargetTokens
                    )
                )
            )
        )
    }

    private func checkSessionTimeout() {
        // Transparent reconnect every ~14 minutes to stay under 15-min session limit
        let timeSinceLastReconnect = Date().timeIntervalSince(lastReconnectTime)
        if timeSinceLastReconnect >= Constants.sessionReconnectDuration && sessionState.isListening {
            performTransparentReconnect()
        }
    }

    /// Attempt a clean reconnect before the 15-minute session limit
    private func performTransparentReconnect() {
        guard let apiKey = KeychainService.retrieve() else { return }

        lastReconnectTime = Date()
        print("[Interpreter] Transparent reconnect at \(Int(sessionState.elapsedTime))s")

        // Disconnect and immediately reconnect
        apiService.disconnect()

        let setup = buildSetupMessage()
        apiService.connect(apiKey: apiKey, setupMessage: setup)
    }
}

// MARK: - GeminiLiveServiceDelegate

extension InterpreterViewModel: GeminiLiveServiceDelegate {
    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveAudioDelta data: Data) {
        playbackService.scheduleAudio(data: data)

        // Track output audio duration (24kHz PCM16 = 2 bytes per sample)
        let seconds = Double(data.count) / (2.0 * Constants.outputSampleRate)
        Task { @MainActor [weak self] in
            self?.sessionState.addOutputAudioDuration(seconds)
            self?.sessionState.isTranslating = true
            self?.outputAudioBytesReceived += data.count
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveAudioDone itemId: String?) {
        Task { @MainActor [weak self] in
            self?.sessionState.isTranslating = false
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveTranscriptDelta text: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentTranscript += text
            self.sessionState.addTranscript(self.currentTranscript, isPartial: true)
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveTranscriptDone text: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.sessionState.finalizeTranscript(text)
            self.currentTranscript = ""
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didDetectSpeechStart itemId: String?) {
        Task { @MainActor [weak self] in
            self?.currentTranscript = ""
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didDetectSpeechStop itemId: String?) {
        // Speech stopped, waiting for model response
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didChangeConnectionStatus status: ConnectionStatus) {
        Task { @MainActor [weak self] in
            self?.sessionState.connectionStatus = status
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didEncounterError error: String) {
        Task { @MainActor [weak self] in
            self?.sessionState.connectionStatus = .error(error)
        }
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveInputTranscription text: String) {
        // Input transcription is what the mic picked up — could log for debug
        print("[Interpreter] Heard: \(text)")
    }

    nonisolated func geminiService(_ service: GeminiLiveService, didReceiveOutputTranscription text: String) {
        // Output transcription is the translation text — use it for the transcript display
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.sessionState.finalizeTranscript(text)
        }
    }
}
