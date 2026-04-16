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
    @Published var selectedVoice: Voice = .alloy
    @Published var showOnboarding: Bool = false

    let sessionState = SessionState()
    let audioSessionManager = AudioSessionManager()

    // MARK: - Private Services

    private let captureService = AudioCaptureService()
    private let playbackService = AudioPlaybackService()
    private let apiService = RealtimeAPIService()

    private var currentTranscript = ""
    private var inputAudioBytesSent: Int = 0
    private var outputAudioBytesReceived: Int = 0

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
            sessionState.connectionStatus = .error("No API key found. Please add your OpenAI API key.")
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

        // Build session config
        let config = buildSessionConfig()

        // Connect to API
        apiService.connect(apiKey: apiKey, sessionConfig: config)

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

            // Track input audio duration
            let seconds = Double(data.count) / (2.0 * Constants.apiSampleRate) // PCM16 = 2 bytes per sample
            Task { @MainActor [weak self] in
                self?.sessionState.addInputAudioDuration(seconds)
                self?.inputAudioBytesSent += data.count
            }
        }

        captureService.onAudioLevel = { [weak self] level in
            Task { @MainActor [weak self] in
                self?.sessionState.inputAudioLevel = level
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

    private func buildSessionConfig() -> SessionUpdateMessage {
        let instructions = Constants.systemPrompt(
            userLanguage: userLanguage.displayName,
            foreignLanguage: foreignLanguage.displayName
        )

        return SessionUpdateMessage(
            session: SessionUpdateMessage.SessionConfig(
                model: "gpt-4o-realtime-preview",
                modalities: ["audio", "text"],
                instructions: instructions,
                voice: selectedVoice.rawValue,
                input_audio_format: "pcm16",
                output_audio_format: "pcm16",
                input_audio_transcription: SessionUpdateMessage.InputAudioTranscription(model: "whisper-1"),
                turn_detection: SessionUpdateMessage.TurnDetection(
                    type: "server_vad",
                    threshold: 0.5,
                    prefix_padding_ms: 300,
                    silence_duration_ms: 500
                )
            )
        )
    }

    private func checkSessionTimeout() {
        if sessionState.elapsedTime >= Constants.sessionMaxDuration {
            stopListening()
        }
    }
}

// MARK: - RealtimeAPIServiceDelegate

extension InterpreterViewModel: RealtimeAPIServiceDelegate {
    nonisolated func realtimeService(_ service: RealtimeAPIService, didReceiveAudioDelta data: Data) {
        playbackService.scheduleAudio(data: data)

        let seconds = Double(data.count) / (2.0 * Constants.apiSampleRate)
        Task { @MainActor [weak self] in
            self?.sessionState.addOutputAudioDuration(seconds)
            self?.sessionState.isTranslating = true
            self?.outputAudioBytesReceived += data.count
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didReceiveAudioDone itemId: String?) {
        Task { @MainActor [weak self] in
            self?.sessionState.isTranslating = false
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didReceiveTranscriptDelta text: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.currentTranscript += text
            self.sessionState.addTranscript(self.currentTranscript, isPartial: true)
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didReceiveTranscriptDone text: String) {
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            self.sessionState.finalizeTranscript(text)
            self.currentTranscript = ""
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didDetectSpeechStart itemId: String?) {
        Task { @MainActor [weak self] in
            self?.currentTranscript = ""
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didDetectSpeechStop itemId: String?) {
        // Speech stopped, waiting for model response
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didChangeConnectionStatus status: ConnectionStatus) {
        Task { @MainActor [weak self] in
            self?.sessionState.connectionStatus = status
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didEncounterError error: String) {
        Task { @MainActor [weak self] in
            self?.sessionState.connectionStatus = .error(error)
        }
    }

    nonisolated func realtimeService(_ service: RealtimeAPIService, didReceiveInputTranscription text: String) {
        // Input transcription is what the mic picked up — could log for debug
        print("[Interpreter] Heard: \(text)")
    }
}
