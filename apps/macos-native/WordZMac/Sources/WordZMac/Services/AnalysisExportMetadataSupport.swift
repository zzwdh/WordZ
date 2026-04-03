import Foundation

enum AnalysisExportMetadataSupport {
    static func notes(
        analysisTitle: String,
        languageMode: AppLanguageMode,
        visibleRows: Int,
        totalRows: Int,
        query: String? = nil,
        queryLabel: String? = nil,
        searchOptions: SearchOptionsState? = nil,
        stopwordFilter: StopwordFilterState? = nil,
        additionalLines: [String] = []
    ) -> [String] {
        var lines = [
            "\(wordZText("分析", "Analysis", mode: languageMode)): \(analysisTitle)",
            "\(wordZText("导出范围", "Export Scope", mode: languageMode)): \(wordZText("当前可见行", "Visible rows", mode: languageMode)) \(visibleRows) / \(totalRows)"
        ]

        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedQuery.isEmpty {
            let resolvedQueryLabel = queryLabel ?? wordZText("检索条件", "Query", mode: languageMode)
            lines.append("\(resolvedQueryLabel): \(trimmedQuery)")
            if let searchOptions {
                lines.append("\(wordZText("匹配方式", "Matching", mode: languageMode)): \(searchOptions.summaryText(in: languageMode))")
            }
        }

        if let stopwordFilter, stopwordFilter.enabled {
            lines.append("\(wordZText("停用词", "Stopwords", mode: languageMode)): \(stopwordFilter.summaryText(in: languageMode))")
        }

        lines.append(contentsOf: additionalLines)
        return lines
    }
}
