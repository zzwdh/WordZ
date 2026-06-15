import Foundation
import WordZShared

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func kwicRows(
        for scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        let sceneRows: [KWICSceneRow]
        switch scope {
        case .current:
            sceneRows = features.kwic.selectedSceneRow.map { [$0] } ?? []
        case .visible:
            sceneRows = features.kwic.scene?.rows ?? []
        }
        return sceneRows.map {
            ConcordanceSavedSetRow(
                id: $0.id,
                sentenceId: $0.sentenceId,
                sentenceTokenIndex: $0.sentenceTokenIndex,
                status: "",
                leftContext: $0.leftContext,
                keyword: $0.keyword,
                rightContext: $0.rightContext,
                concordanceText: $0.concordanceText,
                citationText: $0.citationText,
                fullSentenceText: joinedSentence(
                    left: $0.leftContext,
                    keyword: $0.keyword,
                    right: $0.rightContext
                )
            )
        }
    }

    func locatorRows(
        for scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet
    ) -> [ConcordanceSavedSetRow] {
        let sceneRows: [LocatorSceneRow]
        switch scope {
        case .current:
            sceneRows = features.locator.selectedSceneRow.map { [$0] } ?? []
        case .visible:
            sceneRows = features.locator.scene?.rows ?? []
        }
        return sceneRows.map {
            ConcordanceSavedSetRow(
                id: $0.id,
                sentenceId: $0.sentenceId,
                sentenceTokenIndex: $0.sourceCandidate.nodeIndex,
                status: $0.status,
                leftContext: $0.leftWords,
                keyword: $0.nodeWord,
                rightContext: $0.rightWords,
                concordanceText: $0.concordanceText,
                citationText: $0.citationText,
                fullSentenceText: $0.text
            )
        }
    }

    func currentOpenedScopeCorpus(features: WorkspaceFeatureSet) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else { return nil }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
    }

    func defaultKWICSavedSetName(query: String, scope: ConcordanceSavedSetScope) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = scope == .current
            ? wordZText("当前行", "Current Row", mode: .system)
            : wordZText("当前页", "Visible Rows", mode: .system)
        if trimmedQuery.isEmpty {
            return wordZText("KWIC 命中集", "KWIC Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedQuery + " · " + suffix
    }

    func defaultLocatorSavedSetName(query: String, scope: ConcordanceSavedSetScope) -> String {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = scope == .current
            ? wordZText("当前句", "Current Sentence", mode: .system)
            : wordZText("当前页", "Visible Rows", mode: .system)
        if trimmedQuery.isEmpty {
            return wordZText("Locator 命中集", "Locator Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedQuery + " · " + suffix
    }

    func joinedSentence(left: String, keyword: String, right: String) -> String {
        [left, keyword, right]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func preferredLocatorSourceRow(in set: ConcordanceSavedSet) -> ConcordanceSavedSetRow? {
        if let sourceSentenceId = set.sourceSentenceId,
           let matchingRow = set.rows.first(where: { $0.sentenceId == sourceSentenceId }) {
            return matchingRow
        }
        return set.rows.first
    }

    func savedSet(
        _ set: ConcordanceSavedSet,
        replacingRows rows: [ConcordanceSavedSetRow]
    ) -> ConcordanceSavedSet {
        ConcordanceSavedSet(
            id: set.id,
            name: set.name,
            kind: set.kind,
            corpusID: set.corpusID,
            corpusName: set.corpusName,
            query: set.query,
            sourceSentenceId: set.sourceSentenceId,
            leftWindow: set.leftWindow,
            rightWindow: set.rightWindow,
            searchOptions: set.searchOptions,
            stopwordFilter: set.stopwordFilter,
            createdAt: set.createdAt,
            updatedAt: set.updatedAt,
            notes: set.notes,
            rows: rows
        )
    }

    func resolvedSavedSetKeyword(
        _ set: ConcordanceSavedSet,
        fallback: String = ""
    ) -> String {
        let trimmedQuery = set.query.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return trimmedQuery
        }
        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty {
            return trimmedFallback
        }
        return set.rows.first?.keyword.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func defaultRefinedSavedSetName(baseName: String) -> String {
        let trimmedBaseName = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = wordZText("精炼", "Refined", mode: .system)
        if trimmedBaseName.isEmpty {
            return wordZText("命中集", "Hit Set", mode: .system) + " · " + suffix
        }
        return trimmedBaseName + " · " + suffix
    }

    func normalizedSavedSetNotes(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func slug(_ value: String, fallback: String) -> String {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
        return normalized.isEmpty ? fallback : normalized
    }
}
