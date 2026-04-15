import Foundation
import SwiftUI
import WordZShared

private let wordZModuleBundle = WordZSharedResources.bundle
private let wordZIsRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

package enum AppLanguageMode: String, Codable, CaseIterable, Identifiable {
    case system
    case chinese
    case english

    package var id: String { rawValue }

    var pickerLabel: String {
        pickerLabel(in: WordZLocalization.resolveSystemMode())
    }

    func pickerLabel(in displayMode: AppLanguageMode) -> String {
        switch self {
        case .system:
            return l10n("跟随系统", table: "Settings", mode: displayMode, fallback: "Follow System")
        case .chinese:
            return l10n("中文", table: "Settings", mode: displayMode, fallback: "Chinese")
        case .english:
            return l10n("英文", table: "Settings", mode: displayMode, fallback: "English")
        }
    }

    package init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case Self.system.rawValue:
            self = .system
        case Self.chinese.rawValue, Self.english.rawValue:
            self = .system
        case "bilingual":
            self = .system
        default:
            self = .system
        }
    }
}

@MainActor
package final class WordZLocalization: ObservableObject {
    package static let shared = WordZLocalization()

    @Published private(set) var preferredMode: AppLanguageMode = .system

    var effectiveMode: AppLanguageMode {
        Self.resolveEffectiveMode(for: preferredMode)
    }

    var locale: Locale {
        Self.locale(for: preferredMode)
    }

    func updatePreferredMode(_ mode: AppLanguageMode) {
        let normalizedMode = Self.normalizedPreferredMode(mode)
        guard preferredMode != normalizedMode else { return }
        preferredMode = normalizedMode
    }

    func text(_ key: String, table: String? = nil, fallback: String? = nil) -> String {
        Self.text(forKey: key, table: table, mode: preferredMode, fallback: fallback)
    }

    func text(_ zh: String, _ en: String) -> String {
        Self.text(forKey: zh, mode: preferredMode, fallback: en)
    }

    func format(_ key: String, table: String? = nil, fallback: String? = nil, _ args: CVarArg...) -> String {
        Self.formatted(forKey: key, table: table, mode: preferredMode, fallback: fallback, arguments: args)
    }

    nonisolated static func resolveSystemMode() -> AppLanguageMode {
        if wordZIsRunningTests {
            return .chinese
        }
        let preferredLanguage = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferredLanguage.hasPrefix("zh") ? .chinese : .english
    }

    nonisolated static func resolveEffectiveMode(for preferredMode: AppLanguageMode) -> AppLanguageMode {
        preferredMode == .system ? resolveSystemMode() : preferredMode
    }

    nonisolated static func locale(for preferredMode: AppLanguageMode) -> Locale {
        switch resolveEffectiveMode(for: preferredMode) {
        case .system:
            return .autoupdatingCurrent
        case .chinese:
            return Locale(identifier: "zh-Hans")
        case .english:
            return Locale(identifier: "en")
        }
    }

    nonisolated static func bundle(for preferredMode: AppLanguageMode) -> Bundle {
        switch resolveEffectiveMode(for: preferredMode) {
        case .system:
            return wordZModuleBundle
        case .chinese:
            return localizedBundle(named: "zh-Hans")
        case .english:
            return localizedBundle(named: "en")
        }
    }

    nonisolated static func text(
        forKey key: String,
        table: String? = nil,
        mode: AppLanguageMode,
        fallback: String? = nil
    ) -> String {
        let effectiveMode = resolveEffectiveMode(for: mode)
        if let localized = localizedString(forKey: key, table: table, languageCode: languageCode(for: effectiveMode)) {
            return localized
        }
        switch effectiveMode {
        case .english:
            return fallback ?? key
        case .system, .chinese:
            return key
        }
    }

    nonisolated static func formatted(
        forKey key: String,
        table: String? = nil,
        mode: AppLanguageMode,
        fallback: String? = nil,
        arguments: [CVarArg]
    ) -> String {
        let format = text(forKey: key, table: table, mode: mode, fallback: fallback)
        return String(format: format, locale: locale(for: mode), arguments: arguments)
    }

    nonisolated static func localizedDateTimeString(
        from date: Date,
        mode: AppLanguageMode,
        dateStyle: DateFormatter.Style = .medium,
        timeStyle: DateFormatter.Style = .short
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale(for: mode)
        formatter.timeZone = .current
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: date)
    }

    nonisolated private static func localizedBundle(named languageCode: String) -> Bundle {
        let bundleURL = wordZModuleBundle.url(forResource: languageCode, withExtension: "lproj")
            ?? wordZModuleBundle.url(forResource: languageCode.lowercased(), withExtension: "lproj")
        guard let bundleURL,
              let bundle = Bundle(url: bundleURL) else {
            return wordZModuleBundle
        }
        return bundle
    }

    nonisolated private static func languageCode(for mode: AppLanguageMode) -> String {
        switch mode {
        case .system, .chinese:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }

    nonisolated private static func localizedString(
        forKey key: String,
        table: String?,
        languageCode: String
    ) -> String? {
        let tableName = table ?? "Localizable"
        guard let path = wordZModuleBundle.path(
            forResource: tableName,
            ofType: "strings",
            inDirectory: nil,
            forLocalization: languageCode
        ) ?? wordZModuleBundle.path(
            forResource: tableName,
            ofType: "strings",
            inDirectory: nil,
            forLocalization: languageCode.lowercased()
        ),
        let strings = NSDictionary(contentsOfFile: path) as? [String: String],
        let localized = strings[key] else {
            return nil
        }
        return localized
    }

    nonisolated static func normalizedPreferredMode(_ mode: AppLanguageMode) -> AppLanguageMode {
        _ = mode
        return .system
    }
}

func wordZText(_ zh: String, _ en: String, mode: AppLanguageMode) -> String {
    WordZLocalization.text(forKey: zh, mode: mode, fallback: en)
}

func l10n(_ key: String, table: String? = nil, mode: AppLanguageMode = .system, fallback: String? = nil) -> String {
    WordZLocalization.text(forKey: key, table: table, mode: mode, fallback: fallback)
}

func l10nFormat(
    _ key: String,
    table: String? = nil,
    mode: AppLanguageMode = .system,
    fallback: String? = nil,
    _ args: CVarArg...
) -> String {
    WordZLocalization.formatted(forKey: key, table: table, mode: mode, fallback: fallback, arguments: args)
}

struct L10nText: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let key: String
    let table: String?
    let fallback: String?

    init(_ key: String, table: String? = nil, fallback: String? = nil) {
        self.key = key
        self.table = table
        self.fallback = fallback
    }

    var body: some View {
        Text(l10n(key, table: table, mode: languageMode, fallback: fallback))
    }
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

extension View {
    package func wordZLocalizedEnvironment(_ localization: WordZLocalization) -> some View {
        environmentObject(localization)
            .environment(\.wordZLanguageMode, localization.effectiveMode)
            .environment(\.locale, localization.locale)
    }
}
