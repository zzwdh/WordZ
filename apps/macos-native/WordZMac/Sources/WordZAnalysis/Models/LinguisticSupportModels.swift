import Foundation

package enum TokenScript: String, CaseIterable, Identifiable, Codable, Sendable {
    case latin
    case cjk
    case numeric
    case mixed
    case other

    package var id: String { rawValue }
}

package enum TokenLexicalClass: String, CaseIterable, Identifiable, Codable, Sendable {
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

    package var id: String { rawValue }
}

package struct TokenLinguisticAnnotations: Hashable, Codable, Sendable {
    package let script: TokenScript
    package let lemma: String?
    package let lexicalClass: TokenLexicalClass?

    package static let empty = TokenLinguisticAnnotations(script: .other, lemma: nil, lexicalClass: nil)

    package init(
        script: TokenScript,
        lemma: String?,
        lexicalClass: TokenLexicalClass?
    ) {
        self.script = script
        self.lemma = lemma
        self.lexicalClass = lexicalClass
    }
}

package enum TokenLemmaStrategy: String, CaseIterable, Identifiable, Codable, Sendable {
    case normalizedSurface
    case lemmaPreferred

    package var id: String { rawValue }

    package func resolvedToken(normalized: String, annotations: TokenLinguisticAnnotations) -> String {
        switch self {
        case .normalizedSurface:
            return normalized
        case .lemmaPreferred:
            return annotations.lemma ?? normalized
        }
    }
}

package enum TokenizeLanguagePreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case mixedChineseEnglish
    case latinFocused
    case cjkFocused

    package var id: String { rawValue }

    package func keeps(_ annotations: TokenLinguisticAnnotations) -> Bool {
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
