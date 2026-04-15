import Foundation

extension KeywordPageViewModel {
    var selectedTargetCorpusLabel: String {
        focusSelectionSummary
    }

    var selectedReferenceLabel: String {
        referenceSelectionSummary
    }

    var importedReferenceParseResult: KeywordImportedReferenceParseResult {
        KeywordSuiteAnalyzer.parseImportedReference(importedReferenceListText)
    }

    var focusSelectionSummary: String {
        switch focusSelectionKind {
        case .singleCorpus:
            return selectedTargetCorpusItem()?.name
                ?? wordZText("未选择 Focus 语料", "No focus corpus selected", mode: .system)
        case .selectedCorpora:
            let items = resolvedFocusCorpusItems()
            guard !items.isEmpty else {
                return wordZText("未选择 Focus 语料", "No focus corpora selected", mode: .system)
            }
            let names = items.map(\.name).prefix(3).joined(separator: " · ")
            let suffix = items.count > 3 ? " +\(items.count - 3)" : ""
            return "\(wordZText("合并", "Pooled", mode: .system)) \(items.count) · \(names)\(suffix)"
        case .namedCorpusSet:
            return selectedFocusCorpusSet()?.name
                ?? wordZText("未选择命名语料集", "No named corpus set selected", mode: .system)
        }
    }

    var referenceSelectionSummary: String {
        switch referenceSourceKind {
        case .singleCorpus:
            return selectedReferenceCorpusItem()?.name
                ?? wordZText("未选择 Reference 语料", "No reference corpus selected", mode: .system)
        case .namedCorpusSet:
            return selectedReferenceCorpusSet()?.name
                ?? wordZText("未选择命名参考集", "No named reference set selected", mode: .system)
        case .importedWordList:
            let count = importedReferenceParseResult.acceptedItemCount
            if count == 0 {
                return wordZText("未导入词表", "No imported word list", mode: .system)
            }
            return "\(wordZText("导入词表", "Imported Word List", mode: .system)) · \(count)"
        }
    }

    var workflowReferenceSummary: String {
        switch referenceSourceKind {
        case .singleCorpus:
            return selectedReferenceCorpusItem()?.name ?? ""
        case .namedCorpusSet:
            return selectedReferenceCorpusSet()?.name ?? ""
        case .importedWordList:
            if importedReferenceParseResult.items.isEmpty {
                return ""
            }
            if let importedReferenceListSourceName,
               !importedReferenceListSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return importedReferenceListSourceName
            }
            return wordZText("导入词表", "Imported Word List", mode: .system)
        }
    }

    var workflowReferenceDetail: String {
        switch referenceSourceKind {
        case .singleCorpus:
            return selectedReferenceCorpusItem()?.folderName ?? ""
        case .namedCorpusSet:
            guard let selectedReferenceCorpusSet = selectedReferenceCorpusSet() else { return "" }
            return "\(selectedReferenceCorpusSet.corpusIDs.count) \(wordZText("条语料", "corpora", mode: .system))"
        case .importedWordList:
            let parseResult = importedReferenceParseResult
            guard parseResult.totalLineCount > 0 else { return "" }
            return String(
                format: wordZText(
                    "%d 项 · %d/%d 行接受",
                    "%d items · %d/%d lines accepted",
                    mode: .system
                ),
                parseResult.acceptedItemCount,
                parseResult.acceptedLineCount,
                parseResult.totalLineCount
            )
        }
    }

    var importedReferenceParseSummaryText: String {
        let parseResult = importedReferenceParseResult
        guard parseResult.totalLineCount > 0 else { return "" }
        return String(
            format: wordZText(
                "总行数 %d · 接受 %d · 拒绝 %d · 词项 %d",
                "Lines %d · Accepted %d · Rejected %d · Items %d",
                mode: .system
            ),
            parseResult.totalLineCount,
            parseResult.acceptedLineCount,
            parseResult.rejectedLineCount,
            parseResult.acceptedItemCount
        )
    }

    var workflowKeywordEnabled: Bool {
        canRun
    }
}
