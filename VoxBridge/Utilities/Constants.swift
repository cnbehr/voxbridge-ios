import Foundation

enum Constants {
    static let geminiLiveEndpoint = "wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"

    static let geminiModel = "models/gemini-2.5-flash-native-audio-preview"

    static let inputSampleRate: Double = 16_000
    static let outputSampleRate: Double = 24_000
    static let apiChannelCount: UInt32 = 1
    static let captureBufferSize: UInt32 = 4096

    static let websocketPingInterval: TimeInterval = 15
    static let sessionMaxDuration: TimeInterval = 15 * 60 // 15 minutes
    static let sessionWarningDuration: TimeInterval = 13 * 60 // 13 minutes
    static let sessionReconnectDuration: TimeInterval = 14.5 * 60 // 14.5 minutes — attempt transparent reconnect

    static let reconnectBaseDelay: TimeInterval = 1.0
    static let reconnectMaxDelay: TimeInterval = 30.0

    // Pricing per minute (approximate, Gemini Live API)
    // Input: ~$0.003/1K tokens ≈ $0.0045/min
    // Output: ~$0.012/1K tokens ≈ $0.018/min
    static let audioInputCostPerMinute: Double = 0.0045
    static let audioOutputCostPerMinute: Double = 0.018

    static let keychainServiceName = "com.voxbridge.gemini-apikey"
    static let keychainAccountName = "google-ai-api-key"

    // Context window compression for extended sessions
    static let contextWindowTargetTokens = 10000

    static func systemPrompt(userLanguage: String, foreignLanguage: String) -> String {
        """
        You are an invisible real-time interpreter whispering in the user's ear through their headphones.

        The user understands \(userLanguage). You are listening to ambient audio that may contain speech in multiple languages.

        Your job:
        1. ONLY translate speech that is in \(foreignLanguage) into \(userLanguage)
        2. If you hear \(userLanguage) speech, stay COMPLETELY SILENT — do not translate it
        3. When multiple people speak \(foreignLanguage), translate each speaker naturally with brief pauses
        4. Output ONLY the spoken translation — never add commentary, never say "someone said" or "they're saying"
        5. Match the speaker's tone, urgency, and register
        6. If speech is unclear or too quiet to understand, stay silent rather than guessing
        7. Be concise — translate the meaning, don't pad with extra words
        """
    }
}
