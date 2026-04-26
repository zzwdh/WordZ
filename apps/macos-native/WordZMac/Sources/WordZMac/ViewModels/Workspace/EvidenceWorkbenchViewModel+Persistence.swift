import Foundation

extension EvidenceWorkbenchViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        reviewFilter = snapshot.evidenceReviewFilter
        sourceFilter = snapshot.evidenceSourceFilter
        sentimentFilter = snapshot.evidenceSentimentFilter
        tagFilterQuery = snapshot.evidenceTagFilterQuery
        corpusFilterQuery = snapshot.evidenceCorpusFilterQuery
        normalizeSelection()
        syncEditorState()
    }

    func exportScopeSummary(in mode: AppLanguageMode) -> String {
        var parts: [String] = []
        if reviewFilter != .all {
            parts.append(wordZText("审阅", "Review", mode: mode) + ": " + reviewFilter.title(in: mode))
        }
        if sourceFilter != .all {
            parts.append(wordZText("来源", "Source", mode: mode) + ": " + sourceFilter.title(in: mode))
        }
        if sentimentFilter != .all {
            parts.append(wordZText("情感", "Sentiment", mode: mode) + ": " + sentimentFilter.title(in: mode))
        }
        if let tagQuery = normalizedText(tagFilterQuery) {
            parts.append(wordZText("标签", "Tags", mode: mode) + ": " + tagQuery)
        }
        if let corpusQuery = normalizedText(corpusFilterQuery) {
            parts.append(wordZText("语料", "Corpus", mode: mode) + ": " + corpusQuery)
        }
        return parts.isEmpty ? wordZText("全部证据", "All evidence", mode: mode) : parts.joined(separator: " · ")
    }
}
