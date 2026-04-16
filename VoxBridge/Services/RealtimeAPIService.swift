import Foundation

protocol RealtimeAPIServiceDelegate: AnyObject {
    func realtimeService(_ service: RealtimeAPIService, didReceiveAudioDelta data: Data)
    func realtimeService(_ service: RealtimeAPIService, didReceiveAudioDone itemId: String?)
    func realtimeService(_ service: RealtimeAPIService, didReceiveTranscriptDelta text: String)
    func realtimeService(_ service: RealtimeAPIService, didReceiveTranscriptDone text: String)
    func realtimeService(_ service: RealtimeAPIService, didDetectSpeechStart itemId: String?)
    func realtimeService(_ service: RealtimeAPIService, didDetectSpeechStop itemId: String?)
    func realtimeService(_ service: RealtimeAPIService, didChangeConnectionStatus status: ConnectionStatus)
    func realtimeService(_ service: RealtimeAPIService, didEncounterError error: String)
    func realtimeService(_ service: RealtimeAPIService, didReceiveInputTranscription text: String)
}

final class RealtimeAPIService: NSObject {
    weak var delegate: RealtimeAPIServiceDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pingTimer: Timer?
    private var reconnectAttempt = 0
    private var shouldReconnect = false
    private var apiKey: String = ""
    private var sessionConfig: SessionUpdateMessage?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var isConnected = false

    func connect(apiKey: String, sessionConfig: SessionUpdateMessage) {
        self.apiKey = apiKey
        self.sessionConfig = sessionConfig
        self.shouldReconnect = true
        self.reconnectAttempt = 0

        performConnect()
    }

    func disconnect() {
        shouldReconnect = false
        stopPingTimer()
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        delegate?.realtimeService(self, didChangeConnectionStatus: .disconnected)
    }

    func sendAudio(_ data: Data) {
        guard isConnected else { return }

        let base64Audio = data.base64EncodedString()
        let message = InputAudioBufferAppend(audio: base64Audio)

        guard let jsonData = try? encoder.encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("[RealtimeAPI] Send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func performConnect() {
        delegate?.realtimeService(self, didChangeConnectionStatus: .connecting)

        guard let url = URL(string: Constants.realtimeAPIEndpoint) else {
            delegate?.realtimeService(self, didEncounterError: "Invalid API endpoint URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Constants.openAIBetaHeader, forHTTPHeaderField: "OpenAI-Beta")

        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true

        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessage()
    }

    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("[RealtimeAPI] Receive error: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        guard let messageType = try? decoder.decode(ServerMessageType.self, from: data) else {
            print("[RealtimeAPI] Failed to decode message type")
            return
        }

        switch messageType.type {
        case "session.created":
            handleSessionCreated(data)
        case "session.updated":
            print("[RealtimeAPI] Session updated successfully")
        case "response.audio.delta":
            handleAudioDelta(data)
        case "response.audio.done":
            handleAudioDone(data)
        case "response.audio_transcript.delta":
            handleTranscriptDelta(data)
        case "response.audio_transcript.done":
            handleTranscriptDone(data)
        case "input_audio_buffer.speech_started":
            handleSpeechStarted(data)
        case "input_audio_buffer.speech_stopped":
            handleSpeechStopped(data)
        case "conversation.item.input_audio_transcription.completed":
            handleInputTranscription(data)
        case "response.created":
            print("[RealtimeAPI] Response created")
        case "response.done":
            handleResponseDone(data)
        case "error":
            handleError(data)
        case "rate_limits.updated":
            break // Silently handle rate limit updates
        default:
            print("[RealtimeAPI] Unhandled message type: \(messageType.type)")
        }
    }

    private func handleSessionCreated(_ data: Data) {
        print("[RealtimeAPI] Session created")
        isConnected = true
        reconnectAttempt = 0
        delegate?.realtimeService(self, didChangeConnectionStatus: .connected)

        // Send session configuration
        if let config = sessionConfig {
            sendSessionUpdate(config)
        }

        startPingTimer()
    }

    private func sendSessionUpdate(_ config: SessionUpdateMessage) {
        guard let jsonData = try? encoder.encode(config),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[RealtimeAPI] Failed to encode session update")
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("[RealtimeAPI] Session update send error: \(error.localizedDescription)")
            } else {
                print("[RealtimeAPI] Session update sent")
            }
        }
    }

    private func handleAudioDelta(_ data: Data) {
        guard let message = try? decoder.decode(ResponseAudioDelta.self, from: data) else { return }
        guard let audioData = Data(base64Encoded: message.delta) else { return }
        delegate?.realtimeService(self, didReceiveAudioDelta: audioData)
    }

    private func handleAudioDone(_ data: Data) {
        let message = try? decoder.decode(ResponseAudioDone.self, from: data)
        delegate?.realtimeService(self, didReceiveAudioDone: message?.item_id)
    }

    private func handleTranscriptDelta(_ data: Data) {
        guard let message = try? decoder.decode(ResponseAudioTranscriptDelta.self, from: data) else { return }
        delegate?.realtimeService(self, didReceiveTranscriptDelta: message.delta)
    }

    private func handleTranscriptDone(_ data: Data) {
        guard let message = try? decoder.decode(ResponseAudioTranscriptDone.self, from: data) else { return }
        delegate?.realtimeService(self, didReceiveTranscriptDone: message.transcript)
    }

    private func handleSpeechStarted(_ data: Data) {
        let message = try? decoder.decode(InputAudioBufferSpeechStarted.self, from: data)
        delegate?.realtimeService(self, didDetectSpeechStart: message?.item_id)
    }

    private func handleSpeechStopped(_ data: Data) {
        let message = try? decoder.decode(InputAudioBufferSpeechStopped.self, from: data)
        delegate?.realtimeService(self, didDetectSpeechStop: message?.item_id)
    }

    private func handleInputTranscription(_ data: Data) {
        guard let message = try? decoder.decode(ConversationItemInputAudioTranscriptionCompleted.self, from: data),
              let transcript = message.transcript else { return }
        delegate?.realtimeService(self, didReceiveInputTranscription: transcript)
    }

    private func handleResponseDone(_ data: Data) {
        if let message = try? decoder.decode(ResponseDone.self, from: data) {
            print("[RealtimeAPI] Response done: \(message.response?.status ?? "unknown")")
        }
    }

    private func handleError(_ data: Data) {
        if let message = try? decoder.decode(ErrorMessage.self, from: data) {
            let errorText = message.error?.message ?? "Unknown API error"
            let errorCode = message.error?.code ?? ""
            print("[RealtimeAPI] Error: \(errorCode) - \(errorText)")

            if errorCode == "invalid_api_key" || errorCode == "insufficient_quota" {
                shouldReconnect = false
                delegate?.realtimeService(self, didEncounterError: errorText)
            } else {
                delegate?.realtimeService(self, didEncounterError: errorText)
            }
        }
    }

    private func handleDisconnect() {
        isConnected = false
        stopPingTimer()

        guard shouldReconnect else {
            delegate?.realtimeService(self, didChangeConnectionStatus: .disconnected)
            return
        }

        reconnectAttempt += 1
        let delay = min(
            Constants.reconnectBaseDelay * pow(2.0, Double(reconnectAttempt - 1)),
            Constants.reconnectMaxDelay
        )

        delegate?.realtimeService(self, didChangeConnectionStatus: .reconnecting(attempt: reconnectAttempt))

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self, self.shouldReconnect else { return }
            self.performConnect()
        }
    }

    // MARK: - Ping/Keepalive

    private func startPingTimer() {
        stopPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: Constants.websocketPingInterval, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { error in
                if let error = error {
                    print("[RealtimeAPI] Ping error: \(error.localizedDescription)")
                }
            }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}

// MARK: - URLSessionWebSocketDelegate

extension RealtimeAPIService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[RealtimeAPI] WebSocket connected")
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[RealtimeAPI] WebSocket closed with code: \(closeCode)")
        handleDisconnect()
    }
}
