import Foundation

import WordZWindowing
import WordZShared
@MainActor
extension WorkspaceAnalysisWorkflowService {
    func saveKWICConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.kwic.scene else {
            features.sidebar.setError(wordZText("当前没有可保存的 KWIC 结果。", "There are no KWIC results to save yet.", mode: .system))
            return
        }
        let rows = kwicRows(for: scope, features: features)
        guard !rows.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可保存的 KWIC 命中行。", "There are no KWIC hit rows available to save.", mode: .system))
            return
        }
        guard let source = currentOpenedConcordanceSource(features: features) else {
            features.sidebar.setError(wordZText("当前 KWIC 没有关联语料。", "The current KWIC result is not attached to a corpus.", mode: .system))
            return
        }

        let defaultName = defaultKWICSavedSetName(query: scene.query, scope: scope)
        guard let name = await dialogService.promptText(
            title: wordZText("保存命中集", "Save Hit Set", mode: .system),
            message: wordZText("为当前 KWIC 命中结果输入一个名称。", "Enter a name for the current KWIC hit result.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: .kwic,
            corpusID: source.id,
            corpusName: source.name,
            query: scene.query,
            sourceSentenceId: nil,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptions: scene.searchOptions,
            stopwordFilter: scene.stopwordFilter,
            createdAt: timestamp,
            updatedAt: timestamp,
            rows: rows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存 KWIC 命中集。", "Saved KWIC hit set.", mode: .system),
            features: features
        )
    }

    func saveLocatorConcordanceSavedSet(
        scope: ConcordanceSavedSetScope,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let scene = features.locator.scene else {
            features.sidebar.setError(wordZText("当前没有可保存的 Locator 结果。", "There are no Locator results to save yet.", mode: .system))
            return
        }
        let rows = locatorRows(for: scope, features: features)
        guard !rows.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可保存的 Locator 命中行。", "There are no Locator hit rows available to save.", mode: .system))
            return
        }
        guard let corpus = currentOpenedScopeCorpus(features: features) else {
            features.sidebar.setError(wordZText("当前 Locator 没有关联语料。", "The current Locator result is not attached to a corpus.", mode: .system))
            return
        }

        let defaultName = defaultLocatorSavedSetName(query: scene.source.keyword, scope: scope)
        guard let name = await dialogService.promptText(
            title: wordZText("保存命中集", "Save Hit Set", mode: .system),
            message: wordZText("为当前 Locator 命中结果输入一个名称。", "Enter a name for the current Locator hit result.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: .locator,
            corpusID: corpus.id,
            corpusName: corpus.name,
            query: scene.source.keyword,
            sourceSentenceId: scene.source.sentenceId,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptions: nil,
            stopwordFilter: nil,
            createdAt: timestamp,
            updatedAt: timestamp,
            rows: rows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存 Locator 命中集。", "Saved Locator hit set.", mode: .system),
            features: features
        )
    }

    func saveRefinedConcordanceSavedSet(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features) else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }
        let filteredRows = refinedConcordanceSavedSetRows(kind: kind, features: features)
        guard !filteredRows.isEmpty else {
            features.sidebar.setError(wordZText("当前筛选没有可保存的命中行。", "The current refinement does not contain any rows to save.", mode: .system))
            return
        }

        let defaultName = defaultRefinedSavedSetName(baseName: selectedSet.name)
        guard let name = await dialogService.promptText(
            title: wordZText("保存精炼命中集", "Save Refined Hit Set", mode: .system),
            message: wordZText("为当前筛选后的命中结果输入一个名称。", "Enter a name for the refined hit set.", mode: .system),
            defaultValue: defaultName,
            confirmTitle: wordZText("保存", "Save", mode: .system),
            preferredRoute: preferredRoute
        ) else {
            return
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
        let set = ConcordanceSavedSet(
            id: UUID().uuidString,
            name: name,
            kind: selectedSet.kind,
            corpusID: selectedSet.corpusID,
            corpusName: selectedSet.corpusName,
            query: selectedSet.query,
            sourceSentenceId: selectedSet.sourceSentenceId,
            leftWindow: selectedSet.leftWindow,
            rightWindow: selectedSet.rightWindow,
            searchOptions: selectedSet.searchOptions,
            stopwordFilter: selectedSet.stopwordFilter,
            createdAt: timestamp,
            updatedAt: timestamp,
            notes: normalizedSavedSetNotes(currentSavedSetNotesDraft(kind: kind, features: features)),
            rows: filteredRows
        )

        await saveConcordanceSavedSet(
            set,
            successMessage: wordZText("已保存精炼命中集。", "Saved refined hit set.", mode: .system),
            features: features
        )
    }

    func saveSelectedConcordanceSavedSetNotes(
        kind: ConcordanceSavedSetKind,
        features: WorkspaceFeatureSet
    ) async {
        guard let selectedSet = selectedConcordanceSavedSet(kind: kind, features: features) else {
            features.sidebar.setError(wordZText("请先选择一份已保存命中集。", "Choose a saved hit set first.", mode: .system))
            return
        }

        let nextNotes = normalizedSavedSetNotes(currentSavedSetNotesDraft(kind: kind, features: features))
        if normalizedSavedSetNotes(selectedSet.notes) == nextNotes {
            features.library.setStatus(wordZText("命中集备注没有变化。", "The hit set notes are already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        var updatedSet = selectedSet
        updatedSet.notes = nextNotes
        await saveConcordanceSavedSet(
            updatedSet,
            successMessage: wordZText("已保存命中集备注。", "Saved hit set notes.", mode: .system),
            features: features
        )
    }
}
