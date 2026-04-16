import Foundation
import Combine

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    var displayText: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting: return "Connecting..."
        case .connected: return "Listening..."
        case .reconnecting(let attempt): return "Reconnecting (\(attempt))..."
        case .error(let message): return message
        }
    }

    var isActive: Bool {
        switch self {
        case .connected, .reconnecting: return true
        default: return false
        }
    }
}

@MainActor
final class SessionState: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isListening: Bool = false
    @Published var isTranslating: Bool = false
    @Published var inputAudioLevel: Float = 0.0
    @Published var outputAudioLevel: Float = 0.0
    @Published var elapsedTime: TimeInterval = 0
    @Published var estimatedCost: Double = 0.0
    @Published var transcriptEntries: [TranscriptEntry] = []
    @Published var sessionWarning: String? = nil

    private var sessionStartTime: Date?
    private var timer: Timer?
    private var inputAudioSeconds: Double = 0
    private var outputAudioSeconds: Double = 0

    struct TranscriptEntry: Identifiable {
        let id = UUID()
        let text: String
        let timestamp: Date
        let isPartial: Bool

        var timeString: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm:ss"
            return formatter.string(from: timestamp)
        }
    }

    func startSession() {
        sessionStartTime = Date()
        elapsedTime = 0
        estimatedCost = 0
        inputAudioSeconds = 0
        outputAudioSeconds = 0
        transcriptEntries = []
        sessionWarning = nil
        isListening = true

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateTimer()
            }
        }
    }

    func stopSession() {
        timer?.invalidate()
        timer = nil
        sessionStartTime = nil
        isListening = false
        isTranslating = false
        connectionStatus = .disconnected
    }

    func addInputAudioDuration(_ seconds: Double) {
        inputAudioSeconds += seconds
        updateCost()
    }

    func addOutputAudioDuration(_ seconds: Double) {
        outputAudioSeconds += seconds
        updateCost()
    }

    func addTranscript(_ text: String, isPartial: Bool = false) {
        if isPartial, let lastIndex = transcriptEntries.indices.last, transcriptEntries[lastIndex].isPartial {
            transcriptEntries[lastIndex] = TranscriptEntry(text: text, timestamp: Date(), isPartial: true)
        } else {
            transcriptEntries.append(TranscriptEntry(text: text, timestamp: Date(), isPartial: isPartial))
        }

        // Keep only last 50 entries
        if transcriptEntries.count > 50 {
            transcriptEntries.removeFirst(transcriptEntries.count - 50)
        }
    }

    func finalizeTranscript(_ text: String) {
        // Replace last partial entry or add new
        if let lastIndex = transcriptEntries.indices.last, transcriptEntries[lastIndex].isPartial {
            transcriptEntries[lastIndex] = TranscriptEntry(text: text, timestamp: Date(), isPartial: false)
        } else {
            transcriptEntries.append(TranscriptEntry(text: text, timestamp: Date(), isPartial: false))
        }
    }

    private func updateTimer() {
        guard let start = sessionStartTime else { return }
        elapsedTime = Date().timeIntervalSince(start)

        if elapsedTime >= Constants.sessionMaxDuration {
            sessionWarning = "Session limit reached. Stopping."
        } else if elapsedTime >= Constants.sessionWarningDuration {
            sessionWarning = "Session ending in \(Int((Constants.sessionMaxDuration - elapsedTime) / 60)) minutes"
        }
    }

    private func updateCost() {
        let inputCost = (inputAudioSeconds / 60.0) * Constants.audioInputCostPerMinute
        let outputCost = (outputAudioSeconds / 60.0) * Constants.audioOutputCostPerMinute
        estimatedCost = inputCost + outputCost
    }
}
