import Foundation
import WordZShared

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func loadSelectedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features)
        guard let selectedSet else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }
        let refinedRows = refinedConcordanceSavedSetRows(kind: kind, features: features)
        guard !refinedRows.isEmpty else {
            features.sidebar.setError(wordZText("当前筛选没有可载入的命中行。", "The current refinement does not contain any rows to load.", mode: .system))
            return
        }

        guard features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == selectedSet.corpusID }) else {
            features.sidebar.setError(
                l10nFormat(
                    "命中集“%@”关联的语料已不存在，无法载入。",
                    table: "Errors",
                    mode: .system,
                    fallback: "The corpus linked to hit set \"%@\" is no longer available.",
                    selectedSet.name
                )
            )
            return
        }

        do {
            try await prepareConcordanceSavedSetCorpusSelection(
                selectedSet.corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
            let effectiveSet = savedSet(selectedSet, replacingRows: refinedRows)
            switch kind {
            case .kwic:
                applyKWICSavedSet(effectiveSet, features: features)
            case .locator:
                applyLocatorSavedSet(effectiveSet, features: features)
            }
            features.library.setStatus(
                String(
                    format: wordZText(
                        "已载入命中集“%@”的 %d 行结果。",
                        "Loaded %2$d rows from hit set \"%1$@\".",
                        mode: .system
                    ),
                    selectedSet.name,
                    refinedRows.count
                )
            )
            features.sidebar.clearError()
            markWorkspaceEdited(features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func applyKWICSavedSet(_ set: ConcordanceSavedSet, features: WorkspaceFeatureSet) {
        let keyword = resolvedSavedSetKeyword(set)
        let result = KWICResult(
            rows: set.rows.map { row in
                KWICRow(
                    id: row.id,
                    left: row.leftContext,
                    node: row.keyword,
                    right: row.rightContext,
                    sentenceId: row.sentenceId,
                    sentenceTokenIndex: row.sentenceTokenIndex ?? 0
                )
            }
        )

        features.kwic.applyStateChange(rebuildScene: features.kwic.rebuildScene) {
            features.kwic.keyword = keyword
            features.kwic.leftWindow = "\(set.leftWindow)"
            features.kwic.rightWindow = "\(set.rightWindow)"
            features.kwic.searchOptions = set.searchOptions ?? .default
            features.kwic.stopwordFilter = set.stopwordFilter ?? .default
            features.kwic.result = result
            features.kwic.loadedSavedSetID = set.id
            features.kwic.currentPage = 1
            features.kwic.selectedRowID = result.rows.first?.id
            features.kwic.selectedSavedSetID = set.id
            features.kwic.invalidateCaches()
        }

        if let firstRow = result.rows.first {
            let locatorKeyword = firstRow.node.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? keyword : firstRow.node
            features.locator.updateSource(
                LocatorSource(
                    keyword: locatorKeyword,
                    sentenceId: firstRow.sentenceId,
                    nodeIndex: firstRow.sentenceTokenIndex
                )
            )
        } else {
            features.locator.updateSource(nil)
        }
        features.shell.setSelectedTab(.kwic, notifyTabChange: false)
    }

    func applyLocatorSavedSet(_ set: ConcordanceSavedSet, features: WorkspaceFeatureSet) {
        let sourceRow = preferredLocatorSourceRow(in: set)
        let keyword = resolvedSavedSetKeyword(set, fallback: sourceRow?.keyword ?? "")
        let source = LocatorSource(
            keyword: keyword,
            sentenceId: sourceRow?.sentenceId ?? set.sourceSentenceId ?? 0,
            nodeIndex: sourceRow?.sentenceTokenIndex ?? 0
        )
        let result = LocatorResult(
            sentenceCount: max(Set(set.rows.map(\.sentenceId)).count, set.rows.count),
            rows: set.rows.map { row in
                LocatorRow(
                    sentenceId: row.sentenceId,
                    text: row.fullSentenceText,
                    leftWords: row.leftContext,
                    nodeWord: row.keyword,
                    rightWords: row.rightContext,
                    status: row.status
                )
            }
        )

        features.locator.leftWindow = "\(set.leftWindow)"
        features.locator.rightWindow = "\(set.rightWindow)"
        features.locator.apply(result, source: source, loadedSavedSetID: set.id)
        features.locator.selectedRowID = sourceRow.map { String($0.sentenceId) } ?? result.rows.first.map { String($0.sentenceId) }
        features.locator.selectedSavedSetID = set.id
        features.shell.setSelectedTab(.locator, notifyTabChange: false)
    }

    func prepareConcordanceSavedSetCorpusSelection(
        _ corpusID: String,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        try await prepareDrilldownCorpusSelection(
            corpusID,
            features: features,
            prepareCorpusSelectionChange: prepareCorpusSelectionChange,
            syncFeatureContexts: syncFeatureContexts
        )
    }
}
