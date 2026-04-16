import Foundation

enum Language: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case japanese = "ja"
    case mandarin = "zh"
    case korean = "ko"
    case arabic = "ar"
    case russian = "ru"
    case hindi = "hi"
    case dutch = "nl"
    case swedish = "sv"
    case turkish = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .italian: return "Italian"
        case .portuguese: return "Portuguese"
        case .japanese: return "Japanese"
        case .mandarin: return "Mandarin Chinese"
        case .korean: return "Korean"
        case .arabic: return "Arabic"
        case .russian: return "Russian"
        case .hindi: return "Hindi"
        case .dutch: return "Dutch"
        case .swedish: return "Swedish"
        case .turkish: return "Turkish"
        }
    }

    var nativeName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Espanol"
        case .french: return "Francais"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Portugues"
        case .japanese: return "Nihongo"
        case .mandarin: return "Zhongwen"
        case .korean: return "Hangugeo"
        case .arabic: return "Al-Arabiyyah"
        case .russian: return "Russkiy"
        case .hindi: return "Hindi"
        case .dutch: return "Nederlands"
        case .swedish: return "Svenska"
        case .turkish: return "Turkce"
        }
    }
}

enum Voice: String, CaseIterable, Identifiable, Codable {
    case kore = "Kore"
    case charon = "Charon"
    case fenrir = "Fenrir"
    case aoede = "Aoede"
    case puck = "Puck"
    case leda = "Leda"
    case orus = "Orus"
    case zephyr = "Zephyr"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    /// The voice name sent to the Gemini API
    var geminiVoiceName: String {
        rawValue
    }
}
