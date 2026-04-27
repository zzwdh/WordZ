import Foundation
import NaturalLanguage

package enum LinguisticAnnotationSupport {
    package static func makeAnnotations(
        for token: String,
        in sentenceText: String,
        at index: String.Index,
        tagger: NLTagger
    ) -> TokenLinguisticAnnotations {
        let script = classifyScript(in: token)
        let lemma = normalizedLemma(at: index, in: sentenceText, tagger: tagger)
        let lexicalClass = lexicalClass(at: index, in: sentenceText, tagger: tagger)
        return TokenLinguisticAnnotations(script: script, lemma: lemma, lexicalClass: lexicalClass)
    }

    package static func classifyScript(in token: String) -> TokenScript {
        let scalars = token.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) }
        guard !scalars.isEmpty else { return .other }

        var hasLatin = false
        var hasCJK = false
        var hasNumeric = false
        var hasOtherLetters = false

        for scalar in scalars {
            if CharacterSet.decimalDigits.contains(scalar) {
                hasNumeric = true
                continue
            }
            if isCJK(scalar) {
                hasCJK = true
                continue
            }
            if isLatin(scalar) {
                hasLatin = true
                continue
            }
            if CharacterSet.letters.contains(scalar) {
                hasOtherLetters = true
            }
        }

        let activeGroups = [hasLatin, hasCJK, hasNumeric || hasOtherLetters].filter { $0 }.count
        if activeGroups > 1 || (hasLatin && hasCJK) {
            return .mixed
        }
        if hasLatin { return .latin }
        if hasCJK { return .cjk }
        if hasNumeric { return .numeric }
        return .other
    }

    private static func normalizedLemma(
        at index: String.Index,
        in sentenceText: String,
        tagger: NLTagger
    ) -> String? {
        let (lemmaTag, _) = tagger.tag(at: index, unit: .word, scheme: .lemma)
        let lemma = (lemmaTag?.rawValue ?? "").trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !lemma.isEmpty else { return nil }
        let normalized = AnalysisTextNormalizationSupport.normalizeToken(lemma)
        return normalized.isEmpty ? nil : normalized
    }

    private static func lexicalClass(
        at index: String.Index,
        in sentenceText: String,
        tagger: NLTagger
    ) -> TokenLexicalClass? {
        let (tag, _) = tagger.tag(at: index, unit: .word, scheme: .lexicalClass)
        guard let raw = tag?.rawValue.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        switch raw {
        case "Noun":
            return .noun
        case "Verb":
            return .verb
        case "Adjective":
            return .adjective
        case "Adverb":
            return .adverb
        case "Pronoun":
            return .pronoun
        case "Determiner":
            return .determiner
        case "Preposition":
            return .preposition
        case "Particle":
            return .particle
        case "Conjunction":
            return .conjunction
        case "Interjection":
            return .interjection
        case "Classifier":
            return .classifier
        case "Idiom":
            return .idiom
        case "Number":
            return .number
        default:
            return .other
        }
    }

    private static func isLatin(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x0041...0x007A, 0x00C0...0x024F:
            return CharacterSet.letters.contains(scalar)
        default:
            return false
        }
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x3040...0x30FF,
             0x3400...0x4DBF,
             0x4E00...0x9FFF,
             0xF900...0xFAFF:
            return true
        default:
            return false
        }
    }
}
