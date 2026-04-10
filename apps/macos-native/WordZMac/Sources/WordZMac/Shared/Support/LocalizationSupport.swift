import SwiftUI

enum AppLanguageMode: String, Codable, CaseIterable, Identifiable {
    case system
    case bilingual
    case chinese
    case english

    var id: String { rawValue }

    var pickerLabel: String {
        switch self {
        case .system:
            return "跟随系统 / Follow System"
        case .bilingual:
            return "中英对照 / Bilingual"
        case .chinese:
            return "中文"
        case .english:
            return "English"
        }
    }
}

struct WordZCopy: Equatable {
    let zh: String
    let en: String

    func resolved(in mode: AppLanguageMode) -> String {
        switch mode {
        case .system:
            return resolved(in: WordZLocalization.resolveSystemMode())
        case .bilingual:
            return "\(zh) / \(en)"
        case .chinese:
            return zh
        case .english:
            return en
        }
    }
}

@MainActor
final class WordZLocalization: ObservableObject {
    static let shared = WordZLocalization()

    @Published private(set) var preferredMode: AppLanguageMode = .system

    var effectiveMode: AppLanguageMode {
        switch preferredMode {
        case .system:
            return Self.resolveSystemMode()
        case .bilingual, .chinese, .english:
            return preferredMode
        }
    }

    func updatePreferredMode(_ mode: AppLanguageMode) {
        guard preferredMode != mode else { return }
        preferredMode = mode
    }

    func text(_ zh: String, _ en: String) -> String {
        WordZCopy(zh: zh, en: en).resolved(in: preferredMode)
    }

    nonisolated static func resolveSystemMode() -> AppLanguageMode {
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }
}

func wordZText(_ zh: String, _ en: String, mode: AppLanguageMode) -> String {
    WordZCopy(zh: zh, en: en).resolved(in: mode)
}

private struct WordZLanguageModeKey: EnvironmentKey {
    static let defaultValue: AppLanguageMode = .system
}

extension EnvironmentValues {
    var wordZLanguageMode: AppLanguageMode {
        get { self[WordZLanguageModeKey.self] }
        set { self[WordZLanguageModeKey.self] = newValue }
    }
}
