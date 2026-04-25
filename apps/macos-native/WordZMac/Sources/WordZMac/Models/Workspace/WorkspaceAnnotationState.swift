import Foundation

enum WorkspaceAnnotationProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case surface
    case lemmaPreferred
    case surfaceWithLemmaFallback

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .surface:
            return wordZText("表层词形", "Surface", mode: mode)
        case .lemmaPreferred:
            return wordZText("词形优先", "Lemma Preferred", mode: mode)
        case .surfaceWithLemmaFallback:
            return wordZText("表层词形（词形兜底）", "Surface with Lemma Fallback", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .surface:
            return wordZText("默认使用规范表层词形。", "Use normalized surface tokens by default.", mode: mode)
        case .lemmaPreferred:
            return wordZText("优先使用 lemma，缺失时退回规范词。", "Prefer lemmas and fall back to normalized tokens when missing.", mode: mode)
        case .surfaceWithLemmaFallback:
            return wordZText("优先显示规范词，在解释层补充 lemma。", "Prefer normalized surface forms and surface lemmas as explanatory fallback.", mode: mode)
        }
    }

    var tokenizeLemmaStrategy: TokenLemmaStrategy {
        switch self {
        case .surface, .surfaceWithLemmaFallback:
            return .normalizedSurface
        case .lemmaPreferred:
            return .lemmaPreferred
        }
    }

    var keywordUnit: KeywordUnit {
        switch self {
        case .surface, .surfaceWithLemmaFallback:
            return .normalizedSurface
        case .lemmaPreferred:
            return .lemmaPreferred
        }
    }
}

struct WorkspaceAnnotationState: Equatable, Codable, Sendable {
    var profile: WorkspaceAnnotationProfile
    var lexicalClasses: [TokenLexicalClass]
    var scripts: [TokenScript]

    static let `default` = WorkspaceAnnotationState(
        profile: .surface,
        lexicalClasses: [],
        scripts: []
    )

    init(
        profile: WorkspaceAnnotationProfile = .surface,
        lexicalClasses: [TokenLexicalClass] = [],
        scripts: [TokenScript] = []
    ) {
        self.profile = profile
        self.lexicalClasses = lexicalClasses.uniqueSorted()
        self.scripts = scripts.uniqueSorted()
    }

    var lexicalClassSet: Set<TokenLexicalClass> {
        Set(lexicalClasses)
    }

    var scriptSet: Set<TokenScript> {
        Set(scripts)
    }

    func summary(in mode: AppLanguageMode) -> String {
        var parts = [
            "\(wordZText("标注", "Annotation", mode: mode)): \(profile.title(in: mode))"
        ]

        if scripts.isEmpty {
            parts.append(wordZText("脚本：全部", "Scripts: All", mode: mode))
        } else {
            parts.append(
                "\(wordZText("脚本", "Scripts", mode: mode)): \(scripts.map { $0.title(in: mode) }.joined(separator: ", "))"
            )
        }

        if lexicalClasses.isEmpty {
            parts.append(wordZText("词类：全部", "Classes: All", mode: mode))
        } else {
            parts.append(
                "\(wordZText("词类", "Classes", mode: mode)): \(lexicalClasses.map { $0.title(in: mode) }.joined(separator: ", "))"
            )
        }

        return parts.joined(separator: " · ")
    }

    var jsonObject: JSONObject {
        [
            "profile": profile.rawValue,
            "lexicalClasses": lexicalClasses.map(\.rawValue),
            "scripts": scripts.map(\.rawValue)
        ]
    }
}

private extension Array where Element: RawRepresentable & Hashable, Element.RawValue == String {
    func uniqueSorted() -> [Element] {
        Array(Set(self)).sorted { $0.rawValue < $1.rawValue }
    }
}
