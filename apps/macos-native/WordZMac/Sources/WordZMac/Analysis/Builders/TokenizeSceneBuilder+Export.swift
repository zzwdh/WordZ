import Foundation

extension TokenizeSceneBuilder {
    func buildExportDocument(
        from filteredTokens: [TokenizedToken],
        lemmaStrategy: TokenLemmaStrategy,
        suggestedName: String
    ) -> PlainTextExportDocument? {
        guard !filteredTokens.isEmpty else { return nil }
        let orderedTokens = filteredTokens.sorted {
            if $0.sentenceId == $1.sentenceId {
                return $0.tokenIndex < $1.tokenIndex
            }
            return $0.sentenceId < $1.sentenceId
        }
        let grouped = Dictionary(grouping: orderedTokens, by: \.sentenceId)
        let lines = grouped.keys.sorted().compactMap { sentenceID -> String? in
            guard let tokens = grouped[sentenceID], !tokens.isEmpty else { return nil }
            return tokens
                .map { lemmaStrategy.resolvedToken(normalized: $0.normalized, annotations: $0.annotations) }
                .joined(separator: " ")
        }
        guard !lines.isEmpty else { return nil }
        return PlainTextExportDocument(
            suggestedName: suggestedName,
            text: lines.joined(separator: "\n") + "\n"
        )
    }
}
