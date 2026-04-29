import Foundation

enum SourceReaderSourceChainBuilder {
    static func build(
        context: SourceReaderLaunchContext,
        selectedAnchor: SourceReaderHitAnchor?,
        selection: SourceReaderSelection?,
        hitCount: Int,
        mode: AppLanguageMode
    ) -> [SourceReaderSourceChainItem] {
        var items: [SourceReaderSourceChainItem] = [
            SourceReaderSourceChainItem(
                id: "origin",
                title: wordZText("来源分析", "Origin Analysis", mode: mode),
                value: context.origin.title(in: mode),
                detail: String(
                    format: wordZText("共 %d 条高亮", "%d highlights", mode: mode),
                    hitCount
                ),
                systemImage: symbol(for: context.origin),
                isCurrent: false
            )
        ]

        if let query = normalizedText(context.query) {
            items.append(
                SourceReaderSourceChainItem(
                    id: "query",
                    title: wordZText("查询口径", "Query Scope", mode: mode),
                    value: query,
                    detail: queryDetail(for: context),
                    systemImage: "magnifyingglass",
                    isCurrent: false
                )
            )
        }

        if let corpusName = normalizedText(context.corpusName) {
            items.append(
                SourceReaderSourceChainItem(
                    id: "corpus",
                    title: wordZText("语料", "Corpus", mode: mode),
                    value: corpusName,
                    detail: normalizedText(context.corpusID),
                    systemImage: "books.vertical",
                    isCurrent: false
                )
            )
        }

        if let filePath = normalizedText(context.filePath) {
            items.append(
                SourceReaderSourceChainItem(
                    id: "source-file",
                    title: wordZText("原始文件", "Source File", mode: mode),
                    value: (filePath as NSString).lastPathComponent,
                    detail: filePath,
                    systemImage: "doc.text",
                    isCurrent: false
                )
            )
        }

        if let selectedAnchor {
            items.append(
                SourceReaderSourceChainItem(
                    id: "current-highlight",
                    title: wordZText("当前高亮", "Current Highlight", mode: mode),
                    value: [
                        String(format: wordZText("句 %d", "Sentence %d", mode: mode), selectedAnchor.sentenceId + 1),
                        normalizedText(selectedAnchor.keyword) ?? selection?.keyword
                    ]
                    .compactMap { $0 }
                    .joined(separator: " · "),
                    detail: selection?.hit.fullSentenceText ?? normalizedText(selectedAnchor.fullSentenceText),
                    systemImage: "highlighter",
                    isCurrent: true
                )
            )
        }

        return items
    }

    private static func queryDetail(for context: SourceReaderLaunchContext) -> String? {
        [
            windowSummary(left: context.leftWindow, right: context.rightWindow),
            normalizedText(context.searchOptionsSummary)
        ]
        .compactMap { $0 }
        .joinedOrNil(separator: " · ")
    }

    private static func windowSummary(left: Int?, right: Int?) -> String? {
        guard let left, let right else { return nil }
        return "L\(left) / R\(right)"
    }

    private static func symbol(for origin: SourceReaderOriginFeature) -> String {
        switch origin {
        case .kwic:
            return "quote.opening"
        case .locator:
            return "scope"
        case .plot:
            return "chart.line.uptrend.xyaxis"
        case .sentiment:
            return "waveform.path.ecg.text"
        case .topics:
            return "square.stack.3d.up"
        }
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension Array where Element == String {
    func joinedOrNil(separator: String) -> String? {
        isEmpty ? nil : joined(separator: separator)
    }
}
