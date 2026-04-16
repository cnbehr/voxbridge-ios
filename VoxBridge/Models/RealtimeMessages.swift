import Foundation

// MARK: - Client → Server Messages

struct SessionUpdateMessage: Codable {
    let type: String = "session.update"
    let session: SessionConfig

    struct SessionConfig: Codable {
        let model: String
        let modalities: [String]
        let instructions: String
        let voice: String
        let input_audio_format: String
        let output_audio_format: String
        let input_audio_transcription: InputAudioTranscription?
        let turn_detection: TurnDetection?
    }

    struct InputAudioTranscription: Codable {
        let model: String
    }

    struct TurnDetection: Codable {
        let type: String
        let threshold: Double
        let prefix_padding_ms: Int
        let silence_duration_ms: Int
    }
}

struct InputAudioBufferAppend: Codable {
    let type: String = "input_audio_buffer.append"
    let audio: String // base64 encoded PCM16
}

struct InputAudioBufferClear: Codable {
    let type: String = "input_audio_buffer.clear"
}

// MARK: - Server → Client Messages

/// Generic message to identify the type field
struct ServerMessageType: Codable {
    let type: String
}

struct SessionCreatedMessage: Codable {
    let type: String
    let session: SessionInfo?

    struct SessionInfo: Codable {
        let id: String?
        let model: String?
        let voice: String?
    }
}

struct SessionUpdatedMessage: Codable {
    let type: String
}

struct ResponseAudioDelta: Codable {
    let type: String
    let response_id: String?
    let item_id: String?
    let output_index: Int?
    let content_index: Int?
    let delta: String // base64 encoded audio
}

struct ResponseAudioDone: Codable {
    let type: String
    let response_id: String?
    let item_id: String?
}

struct ResponseAudioTranscriptDelta: Codable {
    let type: String
    let response_id: String?
    let item_id: String?
    let output_index: Int?
    let content_index: Int?
    let delta: String
}

struct ResponseAudioTranscriptDone: Codable {
    let type: String
    let response_id: String?
    let item_id: String?
    let output_index: Int?
    let content_index: Int?
    let transcript: String
}

struct InputAudioBufferSpeechStarted: Codable {
    let type: String
    let audio_start_ms: Int?
    let item_id: String?
}

struct InputAudioBufferSpeechStopped: Codable {
    let type: String
    let audio_end_ms: Int?
    let item_id: String?
}

struct ConversationItemInputAudioTranscriptionCompleted: Codable {
    let type: String
    let item_id: String?
    let content_index: Int?
    let transcript: String?
}

struct ResponseCreated: Codable {
    let type: String
    let response: ResponseInfo?

    struct ResponseInfo: Codable {
        let id: String?
        let status: String?
    }
}

struct ResponseDone: Codable {
    let type: String
    let response: ResponseInfo?

    struct ResponseInfo: Codable {
        let id: String?
        let status: String?
        let usage: UsageInfo?
    }

    struct UsageInfo: Codable {
        let total_tokens: Int?
        let input_tokens: Int?
        let output_tokens: Int?
    }
}

struct ErrorMessage: Codable {
    let type: String
    let error: ErrorDetail?

    struct ErrorDetail: Codable {
        let type: String?
        let code: String?
        let message: String?
    }
}

struct RateLimitsUpdated: Codable {
    let type: String
    let rate_limits: [RateLimit]?

    struct RateLimit: Codable {
        let name: String?
        let limit: Int?
        let remaining: Int?
        let reset_seconds: Double?
    }
}
