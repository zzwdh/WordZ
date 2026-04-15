import Foundation

enum TokenScript: String, CaseIterable, Identifiable, Codable, Sendable {
    case latin
    case cjk
    case numeric
    case mixed
    case other

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .latin:
            return wordZText("拉丁", "Latin", mode: mode)
        case .cjk:
            return wordZText("中日韩", "CJK", mode: mode)
        case .numeric:
            return wordZText("数字", "Numeric", mode: mode)
        case .mixed:
            return wordZText("混合", "Mixed", mode: mode)
        case .other:
            return wordZText("其它", "Other", mode: mode)
        }
    }
}

enum TokenLexicalClass: String, CaseIterable, Identifiable, Codable, Sendable {
    case noun
    case verb
    case adjective
    case adverb
    case pronoun
    case determiner
    case preposition
    case particle
    case conjunction
    case interjection
    case classifier
    case idiom
    case number
    case other

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .noun:
            return wordZText("名词", "Noun", mode: mode)
        case .verb:
            return wordZText("动词", "Verb", mode: mode)
        case .adjective:
            return wordZText("形容词", "Adjective", mode: mode)
        case .adverb:
            return wordZText("副词", "Adverb", mode: mode)
        case .pronoun:
            return wordZText("代词", "Pronoun", mode: mode)
        case .determiner:
            return wordZText("限定词", "Determiner", mode: mode)
        case .preposition:
            return wordZText("介词", "Preposition", mode: mode)
        case .particle:
            return wordZText("小品词", "Particle", mode: mode)
        case .conjunction:
            return wordZText("连词", "Conjunction", mode: mode)
        case .interjection:
            return wordZText("感叹词", "Interjection", mode: mode)
        case .classifier:
            return wordZText("量词", "Classifier", mode: mode)
        case .idiom:
            return wordZText("习语", "Idiom", mode: mode)
        case .number:
            return wordZText("数词", "Number", mode: mode)
        case .other:
            return wordZText("其它", "Other", mode: mode)
        }
    }
}

struct TokenLinguisticAnnotations: Hashable, Codable, Sendable {
    let script: TokenScript
    let lemma: String?
    let lexicalClass: TokenLexicalClass?

    static let empty = TokenLinguisticAnnotations(script: .other, lemma: nil, lexicalClass: nil)

    var jsonObject: JSONObject {
        [
            "script": script.rawValue,
            "lemma": lemma as Any,
            "lexicalClass": lexicalClass?.rawValue as Any
        ]
    }
}

enum TokenLemmaStrategy: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalizedSurface
    case lemmaPreferred

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .normalizedSurface:
            return wordZText("规范词优先", "Normalized surface", mode: mode)
        case .lemmaPreferred:
            return wordZText("词形优先", "Lemma-preferred", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .normalizedSurface:
            return wordZText("沿用当前的小写规范词。", "Keep the current lowercased normalized token.", mode: mode)
        case .lemmaPreferred:
            return wordZText("若系统可给出 lemma，则优先使用 lemma。", "Use system lemmas when available; otherwise fall back to normalized tokens.", mode: mode)
        }
    }

    func resolvedToken(normalized: String, annotations: TokenLinguisticAnnotations) -> String {
        switch self {
        case .normalizedSurface:
            return normalized
        case .lemmaPreferred:
            return annotations.lemma ?? normalized
        }
    }
}

enum TokenizeLanguagePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case mixedChineseEnglish
    case latinFocused
    case cjkFocused

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .mixedChineseEnglish:
            return wordZText("中英混合", "Mixed Zh/En", mode: mode)
        case .latinFocused:
            return wordZText("英文优先", "Latin-focused", mode: mode)
        case .cjkFocused:
            return wordZText("中文优先", "CJK-focused", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .mixedChineseEnglish:
            return wordZText("保留中英和数字 token，适合混合文本。", "Keep CJK, Latin, and numeric tokens for mixed-language texts.", mode: mode)
        case .latinFocused:
            return wordZText("优先保留英文和数字 token，适合英文论文语料。", "Prefer Latin and numeric tokens for English-heavy corpora.", mode: mode)
        case .cjkFocused:
            return wordZText("优先保留中文和数字 token，适合中文语料。", "Prefer CJK and numeric tokens for Chinese-heavy corpora.", mode: mode)
        }
    }

    func keeps(_ annotations: TokenLinguisticAnnotations) -> Bool {
        switch self {
        case .mixedChineseEnglish:
            return annotations.script != .other
        case .latinFocused:
            return [.latin, .numeric, .mixed].contains(annotations.script)
        case .cjkFocused:
            return [.cjk, .numeric, .mixed].contains(annotations.script)
        }
    }
}
