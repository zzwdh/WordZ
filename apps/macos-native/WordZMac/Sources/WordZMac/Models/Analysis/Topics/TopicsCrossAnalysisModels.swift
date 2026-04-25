import Foundation

struct TopicsCompareDrilldownContext: Equatable, Sendable {
    let focusTerm: String
    let targetCorpora: [LibraryCorpusItem]
    let referenceCorpora: [LibraryCorpusItem]

    var targetCorpusIDs: [String] {
        targetCorpora.map(\.id)
    }

    var referenceCorpusIDs: [String] {
        referenceCorpora.map(\.id)
    }

    var hasReferenceScope: Bool {
        !referenceCorpora.isEmpty
    }

    func summaryLine(in mode: AppLanguageMode) -> String {
        [
            wordZText("Compare x Topics 交叉分析", "Compare x Topics cross-analysis", mode: mode),
            "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(joinedCorpusNames(targetCorpora, emptyLabel: wordZText("未选择目标语料", "No target corpora selected", mode: mode)))",
            "\(wordZText("参考语料", "Reference Corpora", mode: mode)): \(joinedCorpusNames(referenceCorpora, emptyLabel: wordZText("未选择参考语料", "No reference corpora selected", mode: mode)))",
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)"
        ]
        .joined(separator: " · ")
    }

    func exportMetadataLines(in mode: AppLanguageMode) -> [String] {
        [
            "\(wordZText("跨分析", "Cross Analysis", mode: mode)): \(wordZText("Compare x Topics", "Compare x Topics", mode: mode))",
            "\(wordZText("目标语料", "Target Corpora", mode: mode)): \(joinedCorpusNames(targetCorpora, emptyLabel: "—"))",
            "\(wordZText("参考语料", "Reference Corpora", mode: mode)): \(joinedCorpusNames(referenceCorpora, emptyLabel: "—"))",
            "\(wordZText("聚焦词项", "Focus Term", mode: mode)): \(focusTerm)"
        ]
    }

    private func joinedCorpusNames(
        _ corpora: [LibraryCorpusItem],
        emptyLabel: String
    ) -> String {
        let names = corpora.map(\.name).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !names.isEmpty else { return emptyLabel }
        return names.joined(separator: " · ")
    }
}
