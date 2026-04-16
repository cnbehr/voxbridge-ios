import Foundation

enum Constants {
    static let realtimeAPIEndpoint = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview"
    static let openAIBetaHeader = "realtime=v1"

    static let apiSampleRate: Double = 24_000
    static let apiChannelCount: UInt32 = 1
    static let captureBufferSize: UInt32 = 4096

    static let websocketPingInterval: TimeInterval = 15
    static let sessionMaxDuration: TimeInterval = 59 * 60 // 59 minutes
    static let sessionWarningDuration: TimeInterval = 55 * 60 // 55 minutes

    static let reconnectBaseDelay: TimeInterval = 1.0
    static let reconnectMaxDelay: TimeInterval = 30.0

    // Pricing per minute (approximate, gpt-realtime-1.5)
    static let audioInputCostPerMinute: Double = 0.06
    static let audioOutputCostPerMinute: Double = 0.24

    static let keychainServiceName = "com.voxbridge.apikey"
    static let keychainAccountName = "openai-api-key"

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
