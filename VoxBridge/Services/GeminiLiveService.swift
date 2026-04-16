import Foundation

protocol GeminiLiveServiceDelegate: AnyObject {
    func geminiService(_ service: GeminiLiveService, didReceiveAudioDelta data: Data)
    func geminiService(_ service: GeminiLiveService, didReceiveAudioDone itemId: String?)
    func geminiService(_ service: GeminiLiveService, didReceiveTranscriptDelta text: String)
    func geminiService(_ service: GeminiLiveService, didReceiveTranscriptDone text: String)
    func geminiService(_ service: GeminiLiveService, didDetectSpeechStart itemId: String?)
    func geminiService(_ service: GeminiLiveService, didDetectSpeechStop itemId: String?)
    func geminiService(_ service: GeminiLiveService, didChangeConnectionStatus status: ConnectionStatus)
    func geminiService(_ service: GeminiLiveService, didEncounterError error: String)
    func geminiService(_ service: GeminiLiveService, didReceiveInputTranscription text: String)
    func geminiService(_ service: GeminiLiveService, didReceiveOutputTranscription text: String)
}

final class GeminiLiveService: NSObject {
    weak var delegate: GeminiLiveServiceDelegate?

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var pingTimer: Timer?
    private var reconnectAttempt = 0
    private var shouldReconnect = false
    private var apiKey: String = ""
    private var setupMessage: GeminiSetupMessage?
    private var isSetupComplete = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var isConnected = false

    func connect(apiKey: String, setupMessage: GeminiSetupMessage) {
        self.apiKey = apiKey
        self.setupMessage = setupMessage
        self.shouldReconnect = true
        self.reconnectAttempt = 0
        self.isSetupComplete = false

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
        isSetupComplete = false
        delegate?.geminiService(self, didChangeConnectionStatus: .disconnected)
    }

    func sendAudio(_ data: Data) {
        guard isConnected, isSetupComplete else { return }

        let base64Audio = data.base64EncodedString()
        let message = GeminiRealtimeInput(
            realtimeInput: GeminiRealtimeInput.AudioPayload(
                audio: GeminiRealtimeInput.AudioData(
                    data: base64Audio,
                    mimeType: "audio/pcm;rate=16000"
                )
            )
        )

        guard let jsonData = try? encoder.encode(message),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("[GeminiLive] Send error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Private

    private func performConnect() {
        delegate?.geminiService(self, didChangeConnectionStatus: .connecting)

        // Append API key as query parameter
        let urlString = "\(Constants.geminiLiveEndpoint)?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            delegate?.geminiService(self, didEncounterError: "Invalid API endpoint URL")
            return
        }

        var request = URLRequest(url: url)
        // No auth headers needed — key is in URL query parameter
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
                print("[GeminiLive] Receive error: \(error.localizedDescription)")
                self.handleDisconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        // Gemini uses top-level keys, not a "type" field
        guard let message = try? decoder.decode(GeminiServerMessage.self, from: data) else {
            print("[GeminiLive] Failed to decode server message")
            // Check for error responses
            if text.contains("\"error\"") {
                handleErrorMessage(text)
            }
            return
        }

        if message.setupComplete != nil {
            handleSetupComplete()
            return
        }

        if let serverContent = message.serverContent {
            handleServerContent(serverContent)
            return
        }

        print("[GeminiLive] Unhandled message: \(text.prefix(200))")
    }

    private func handleSetupComplete() {
        print("[GeminiLive] Setup complete")
        isSetupComplete = true
        isConnected = true
        reconnectAttempt = 0
        delegate?.geminiService(self, didChangeConnectionStatus: .connected)
        startPingTimer()
    }

    private func handleServerContent(_ content: GeminiServerContent) {
        // Handle input transcription (what the user said)
        if let inputTranscription = content.inputTranscription,
           let text = inputTranscription.text, !text.isEmpty {
            delegate?.geminiService(self, didReceiveInputTranscription: text)
        }

        // Handle output transcription (what the model said in translation)
        if let outputTranscription = content.outputTranscription,
           let text = outputTranscription.text, !text.isEmpty {
            delegate?.geminiService(self, didReceiveOutputTranscription: text)
        }

        // Handle model audio response
        if let modelTurn = content.modelTurn, let parts = modelTurn.parts {
            for part in parts {
                if let inlineData = part.inlineData,
                   let base64Audio = inlineData.data,
                   let audioData = Data(base64Encoded: base64Audio) {
                    delegate?.geminiService(self, didReceiveAudioDelta: audioData)
                }
            }
        }

        // Handle turn complete
        if content.turnComplete == true {
            delegate?.geminiService(self, didReceiveAudioDone: nil)
        }
    }

    private func handleErrorMessage(_ text: String) {
        // Try to extract error info from raw JSON
        if let data = text.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Unknown API error"
            let code = error["code"] as? Int
            let status = error["status"] as? String ?? ""
            print("[GeminiLive] Error: \(status) (\(code ?? 0)) - \(message)")

            if status == "UNAUTHENTICATED" || status == "PERMISSION_DENIED" || code == 403 || code == 401 {
                shouldReconnect = false
            }

            delegate?.geminiService(self, didEncounterError: message)
        }
    }

    /// Send the setup message as the first message after WebSocket connects
    private func sendSetup() {
        guard let setup = setupMessage else {
            print("[GeminiLive] No setup message configured")
            return
        }

        guard let jsonData = try? encoder.encode(setup),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("[GeminiLive] Failed to encode setup message")
            return
        }

        webSocketTask?.send(.string(jsonString)) { error in
            if let error = error {
                print("[GeminiLive] Setup send error: \(error.localizedDescription)")
            } else {
                print("[GeminiLive] Setup message sent")
            }
        }
    }

    private func handleDisconnect() {
        isConnected = false
        isSetupComplete = false
        stopPingTimer()

        guard shouldReconnect else {
            delegate?.geminiService(self, didChangeConnectionStatus: .disconnected)
            return
        }

        reconnectAttempt += 1
        let delay = min(
            Constants.reconnectBaseDelay * pow(2.0, Double(reconnectAttempt - 1)),
            Constants.reconnectMaxDelay
        )

        delegate?.geminiService(self, didChangeConnectionStatus: .reconnecting(attempt: reconnectAttempt))

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
                    print("[GeminiLive] Ping error: \(error.localizedDescription)")
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

extension GeminiLiveService: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("[GeminiLive] WebSocket connected, sending setup...")
        sendSetup()
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("[GeminiLive] WebSocket closed with code: \(closeCode)")
        handleDisconnect()
    }
}
