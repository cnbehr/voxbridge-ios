import Foundation

// MARK: - Client → Server Messages

/// First message sent after WebSocket connects to configure the session
struct GeminiSetupMessage: Codable {
    let setup: SetupConfig

    struct SetupConfig: Codable {
        let model: String
        let generationConfig: GenerationConfig
        let systemInstruction: SystemInstruction
        let realtimeInputConfig: RealtimeInputConfig
        let contextWindowCompression: ContextWindowCompression?
    }

    struct GenerationConfig: Codable {
        let responseModalities: [String]
        let speechConfig: SpeechConfig
    }

    struct SpeechConfig: Codable {
        let voiceConfig: VoiceConfig
    }

    struct VoiceConfig: Codable {
        let prebuiltVoiceConfig: PrebuiltVoiceConfig
    }

    struct PrebuiltVoiceConfig: Codable {
        let voiceName: String
    }

    struct SystemInstruction: Codable {
        let parts: [Part]
    }

    struct Part: Codable {
        let text: String
    }

    struct RealtimeInputConfig: Codable {
        let automaticActivityDetection: AutomaticActivityDetection
        let inputAudioTranscription: EmptyConfig
        let outputAudioTranscription: EmptyConfig
    }

    struct AutomaticActivityDetection: Codable {
        let disabled: Bool
    }

    struct EmptyConfig: Codable {}

    struct ContextWindowCompression: Codable {
        let slidingWindow: SlidingWindow
    }

    struct SlidingWindow: Codable {
        let targetTokens: Int
    }
}

/// Send audio data to Gemini
struct GeminiRealtimeInput: Codable {
    let realtimeInput: AudioPayload

    struct AudioPayload: Codable {
        let audio: AudioData
    }

    struct AudioData: Codable {
        let data: String // base64 encoded PCM16 at 16kHz
        let mimeType: String
    }
}

// MARK: - Server → Client Messages

/// Top-level server message — parse by checking which key exists
/// Gemini does NOT use a "type" field; messages have different top-level keys
struct GeminiServerMessage: Codable {
    let setupComplete: GeminiSetupComplete?
    let serverContent: GeminiServerContent?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        setupComplete = try container.decodeIfPresent(GeminiSetupComplete.self, forKey: .setupComplete)
        serverContent = try container.decodeIfPresent(GeminiServerContent.self, forKey: .serverContent)
    }

    private enum CodingKeys: String, CodingKey {
        case setupComplete
        case serverContent
    }
}

/// Server acknowledges setup
struct GeminiSetupComplete: Codable {}

/// Server content wrapper for model responses, transcriptions, and turn state
struct GeminiServerContent: Codable {
    let modelTurn: ModelTurn?
    let turnComplete: Bool?
    let inputTranscription: Transcription?
    let outputTranscription: Transcription?

    struct ModelTurn: Codable {
        let parts: [ModelPart]?
    }

    struct ModelPart: Codable {
        let inlineData: InlineData?
    }

    struct InlineData: Codable {
        let mimeType: String?
        let data: String? // base64 encoded audio
    }

    struct Transcription: Codable {
        let text: String?
    }
}
