import Foundation
import WordZAnalysis

typealias TokenScript = WordZAnalysis.TokenScript
typealias TokenLexicalClass = WordZAnalysis.TokenLexicalClass
typealias TokenLinguisticAnnotations = WordZAnalysis.TokenLinguisticAnnotations
typealias TokenLemmaStrategy = WordZAnalysis.TokenLemmaStrategy
typealias TokenizeLanguagePreset = WordZAnalysis.TokenizeLanguagePreset

extension TokenScript {
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

extension TokenLexicalClass {
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

extension TokenLinguisticAnnotations {
    var jsonObject: JSONObject {
        [
            "script": script.rawValue,
            "lemma": lemma as Any,
            "lexicalClass": lexicalClass?.rawValue as Any
        ]
    }
}

extension TokenLemmaStrategy {
    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .normalizedSurface:
            return wordZText("规范词优先", "Normalized surface", mode: mode)
        case .lemmaPreferred:
            return wordZText("Lemma 优先", "Lemma-preferred", mode: mode)
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
}

extension TokenizeLanguagePreset {
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
}
