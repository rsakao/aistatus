import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case japanese
    case english

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .japanese: Locale(identifier: "ja_JP")
        case .english: Locale(identifier: "en_US")
        }
    }

    var displayName: String {
        switch self {
        case .japanese: "日本語"
        case .english: "English"
        }
    }

    func text(_ japanese: String, _ english: String) -> String {
        switch self {
        case .japanese: japanese
        case .english: english
        }
    }
}
