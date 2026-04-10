import Foundation

extension TokenizeSceneBuilder {
    func sortRows(
        _ rows: [TokenizedToken],
        mode: TokenizeSortMode,
        lemmaStrategy: TokenLemmaStrategy
    ) -> [TokenizedToken] {
        switch mode {
        case .sequenceAscending:
            return rows.sorted(by: sequenceAscending)
        case .sequenceDescending:
            return rows.sorted { sequenceAscending($1, $0) }
        case .originalAscending:
            return rows.sorted {
                compareText($0.original, $1.original, fallback: sequenceAscending($0, $1))
            }
        case .originalDescending:
            return rows.sorted {
                compareText($0.original, $1.original, fallback: sequenceAscending($0, $1), ascending: false)
            }
        case .normalizedAscending:
            return rows.sorted {
                compareText($0.normalized, $1.normalized, fallback: sequenceAscending($0, $1))
            }
        case .normalizedDescending:
            return rows.sorted {
                compareText($0.normalized, $1.normalized, fallback: sequenceAscending($0, $1), ascending: false)
            }
        case .lemmaAscending:
            return rows.sorted {
                compareText(
                    lemmaStrategy.resolvedToken(normalized: $0.normalized, annotations: $0.annotations),
                    lemmaStrategy.resolvedToken(normalized: $1.normalized, annotations: $1.annotations),
                    fallback: sequenceAscending($0, $1)
                )
            }
        case .lemmaDescending:
            return rows.sorted {
                compareText(
                    lemmaStrategy.resolvedToken(normalized: $0.normalized, annotations: $0.annotations),
                    lemmaStrategy.resolvedToken(normalized: $1.normalized, annotations: $1.annotations),
                    fallback: sequenceAscending($0, $1),
                    ascending: false
                )
            }
        case .lexicalClassAscending:
            return rows.sorted {
                compareText(
                    $0.annotations.lexicalClass?.rawValue ?? "",
                    $1.annotations.lexicalClass?.rawValue ?? "",
                    fallback: sequenceAscending($0, $1)
                )
            }
        case .lexicalClassDescending:
            return rows.sorted {
                compareText(
                    $0.annotations.lexicalClass?.rawValue ?? "",
                    $1.annotations.lexicalClass?.rawValue ?? "",
                    fallback: sequenceAscending($0, $1),
                    ascending: false
                )
            }
        case .scriptAscending:
            return rows.sorted {
                compareText(
                    $0.annotations.script.rawValue,
                    $1.annotations.script.rawValue,
                    fallback: sequenceAscending($0, $1)
                )
            }
        case .scriptDescending:
            return rows.sorted {
                compareText(
                    $0.annotations.script.rawValue,
                    $1.annotations.script.rawValue,
                    fallback: sequenceAscending($0, $1),
                    ascending: false
                )
            }
        }
    }

    func sequenceAscending(_ lhs: TokenizedToken, _ rhs: TokenizedToken) -> Bool {
        if lhs.sentenceId == rhs.sentenceId {
            return lhs.tokenIndex < rhs.tokenIndex
        }
        return lhs.sentenceId < rhs.sentenceId
    }

    func compareText(_ lhs: String, _ rhs: String, fallback: Bool, ascending: Bool = true) -> Bool {
        let comparison = lhs.localizedCaseInsensitiveCompare(rhs)
        if comparison == .orderedSame {
            return fallback
        }
        return ascending ? comparison == .orderedAscending : comparison == .orderedDescending
    }

    func sortIndicator(for key: TokenizeColumnKey, sortMode: TokenizeSortMode) -> String? {
        switch (key, sortMode) {
        case (.sentence, .sequenceAscending), (.position, .sequenceAscending),
             (.original, .originalAscending), (.normalized, .normalizedAscending),
             (.lemma, .lemmaAscending), (.lexicalClass, .lexicalClassAscending),
             (.script, .scriptAscending):
            return "↑"
        case (.sentence, .sequenceDescending), (.position, .sequenceDescending),
             (.original, .originalDescending), (.normalized, .normalizedDescending),
             (.lemma, .lemmaDescending), (.lexicalClass, .lexicalClassDescending),
             (.script, .scriptDescending):
            return "↓"
        default:
            return nil
        }
    }
}
