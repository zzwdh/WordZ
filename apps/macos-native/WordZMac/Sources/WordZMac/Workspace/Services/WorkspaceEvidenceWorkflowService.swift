import Foundation

@MainActor
final class WorkspaceEvidenceWorkflowService {
    private let repository: any WorkspaceRepository
    private let sessionStore: WorkspaceSessionStore
    private let dialogService: NativeDialogServicing
    private let hostActionService: any NativeHostActionServicing
    private let exportCoordinator: any WorkspaceExportCoordinating

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.dialogService = dialogService
        self.hostActionService = hostActionService
        self.exportCoordinator = exportCoordinator
    }

    func refreshEvidenceItems(features: WorkspaceFeatureSet) async {
        do {
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func captureCurrentKWICEvidenceItem(features: WorkspaceFeatureSet) async {
        guard let scene = features.kwic.scene, let selectedRow = features.kwic.selectedSceneRow else {
            features.sidebar.setError(wordZText("当前没有可加入的 KWIC 证据条目。", "There is no KWIC row available to add as evidence.", mode: .system))
            return
        }

        let loadedSet = loadedKWICSavedSet(features: features)
        guard let corpus = evidenceCorpusMetadata(features: features, fallbackSet: loadedSet) else {
            features.sidebar.setError(wordZText("当前 KWIC 没有关联语料。", "The current KWIC result is not attached to a corpus.", mode: .system))
            return
        }

        let savedRow = matchingSavedSetRow(for: selectedRow, in: loadedSet)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let item = EvidenceItem(
            id: UUID().uuidString,
            sourceKind: .kwic,
            savedSetID: loadedSet?.id,
            savedSetName: loadedSet?.name,
            corpusID: corpus.id,
            corpusName: corpus.name,
            sentenceId: selectedRow.sentenceId,
            sentenceTokenIndex: selectedRow.sentenceTokenIndex,
            leftContext: selectedRow.leftContext,
            keyword: selectedRow.keyword,
            rightContext: selectedRow.rightContext,
            fullSentenceText: normalizedEvidenceText(
                savedRow?.fullSentenceText ?? joinedEvidenceSentence(
                    left: selectedRow.leftContext,
                    keyword: selectedRow.keyword,
                    right: selectedRow.rightContext
                )
            ),
            citationText: normalizedEvidenceText(savedRow?.citationText ?? selectedRow.citationText),
            query: scene.query,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSnapshot: scene.searchOptions,
            stopwordFilterSnapshot: scene.stopwordFilter,
            reviewStatus: .pending,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        await saveEvidenceItem(
            item,
            successMessage: wordZText("已加入证据工作台。", "Added the row to the evidence workbench.", mode: .system),
            features: features
        )
    }

    func captureCurrentLocatorEvidenceItem(features: WorkspaceFeatureSet) async {
        guard let scene = features.locator.scene, let selectedRow = features.locator.selectedSceneRow else {
            features.sidebar.setError(wordZText("当前没有可加入的定位证据条目。", "There is no locator row available to add as evidence.", mode: .system))
            return
        }

        let loadedSet = loadedLocatorSavedSet(features: features)
        guard let corpus = evidenceCorpusMetadata(features: features, fallbackSet: loadedSet) else {
            features.sidebar.setError(wordZText("当前定位结果没有关联语料。", "The current locator result is not attached to a corpus.", mode: .system))
            return
        }

        let savedRow = matchingSavedSetRow(for: selectedRow, in: loadedSet)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let item = EvidenceItem(
            id: UUID().uuidString,
            sourceKind: .locator,
            savedSetID: loadedSet?.id,
            savedSetName: loadedSet?.name,
            corpusID: corpus.id,
            corpusName: corpus.name,
            sentenceId: selectedRow.sentenceId,
            sentenceTokenIndex: selectedRow.sourceCandidate.nodeIndex,
            leftContext: selectedRow.leftWords,
            keyword: selectedRow.nodeWord,
            rightContext: selectedRow.rightWords,
            fullSentenceText: normalizedEvidenceText(savedRow?.fullSentenceText ?? selectedRow.text),
            citationText: normalizedEvidenceText(savedRow?.citationText ?? selectedRow.citationText),
            query: scene.source.keyword,
            leftWindow: scene.leftWindow,
            rightWindow: scene.rightWindow,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            note: nil,
            createdAt: timestamp,
            updatedAt: timestamp
        )

        await saveEvidenceItem(
            item,
            successMessage: wordZText("已加入证据工作台。", "Added the sentence to the evidence workbench.", mode: .system),
            features: features
        )
    }

    func updateEvidenceReviewStatus(
        itemID: String,
        reviewStatus: EvidenceReviewStatus,
        features: WorkspaceFeatureSet
    ) async {
        guard var existingItem = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要更新的证据条目。", "The evidence item could not be found.", mode: .system))
            return
        }

        if existingItem.reviewStatus == reviewStatus {
            features.library.setStatus(wordZText("证据条目状态没有变化。", "The evidence item status is already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        existingItem.reviewStatus = reviewStatus
        await saveEvidenceItem(
            existingItem,
            successMessage: wordZText("已更新证据条目状态。", "Updated the evidence review status.", mode: .system),
            features: features
        )
    }

    func saveSelectedEvidenceNote(features: WorkspaceFeatureSet) async {
        guard var selectedItem = features.evidenceWorkbench.selectedItem else {
            features.sidebar.setError(wordZText("请先选择一个证据条目。", "Select an evidence item first.", mode: .system))
            return
        }

        let nextNote = features.evidenceWorkbench.normalizedNote(features.evidenceWorkbench.noteDraft)
        if features.evidenceWorkbench.normalizedNote(selectedItem.note) == nextNote {
            features.library.setStatus(wordZText("证据备注没有变化。", "The evidence note is already up to date.", mode: .system))
            features.sidebar.clearError()
            return
        }

        selectedItem.note = nextNote
        await saveEvidenceItem(
            selectedItem,
            successMessage: wordZText("已保存证据备注。", "Saved the evidence note.", mode: .system),
            features: features
        )
    }

    func deleteEvidenceItem(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            try await repository.deleteEvidenceItem(itemID: itemID)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            features.library.setStatus(wordZText("已删除证据条目。", "Deleted the evidence item.", mode: .system))
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func copyEvidenceCitation(
        itemID: String,
        features: WorkspaceFeatureSet
    ) async {
        guard let item = features.evidenceWorkbench.items.first(where: { $0.id == itemID }) else {
            features.sidebar.setError(wordZText("未找到要复制的证据条目。", "The evidence item could not be found.", mode: .system))
            return
        }
        hostActionService.copyTextToClipboard(item.citationText)
        features.library.setStatus(wordZText("已复制证据引文。", "Copied the evidence citation.", mode: .system))
        features.sidebar.clearError()
    }

    func exportEvidencePacketMarkdown(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        do {
            let document = try EvidenceMarkdownPacketSupport.document(items: features.evidenceWorkbench.items)
            await exportTextDocument(
                document,
                title: wordZText("导出证据包 Markdown", "Export Evidence Packet Markdown", mode: .system),
                successStatus: wordZText("已导出证据包到", "Exported the evidence packet to", mode: .system),
                features: features,
                preferredRoute: preferredRoute
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func exportEvidenceJSON(
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        guard !features.evidenceWorkbench.items.isEmpty else {
            features.sidebar.setError(wordZText("当前没有可导出的证据条目。", "There are no evidence items to export.", mode: .system))
            return
        }

        guard let path = await dialogService.chooseSavePath(
            title: wordZText("导出证据 JSON", "Export Evidence JSON", mode: .system),
            suggestedName: "evidence-workbench.json",
            allowedExtension: "json",
            preferredRoute: preferredRoute
        ) else {
            return
        }

        do {
            let data = try EvidenceTransferSupport.exportData(items: features.evidenceWorkbench.items)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
            features.library.setStatus(wordZText("已导出证据 JSON 到", "Exported evidence JSON to", mode: .system) + " " + path)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func saveEvidenceItem(
        _ item: EvidenceItem,
        successMessage: String,
        features: WorkspaceFeatureSet
    ) async {
        do {
            let savedItem = try await repository.saveEvidenceItem(item)
            let items = try await repository.listEvidenceItems()
            applyEvidenceItems(items, features: features)
            restoreEvidenceSelection(afterSaving: savedItem, features: features)
            features.library.setStatus(successMessage)
            features.sidebar.clearError()
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func exportTextDocument(
        _ document: PlainTextExportDocument,
        title: String,
        successStatus: String,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute?
    ) async {
        do {
            if let savedPath = try await exportCoordinator.export(
                textDocument: document,
                title: title,
                preferredRoute: preferredRoute
            ) {
                features.library.setStatus("\(successStatus) \(savedPath)")
                features.sidebar.clearError()
            }
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    private func applyEvidenceItems(
        _ items: [EvidenceItem],
        features: WorkspaceFeatureSet
    ) {
        features.evidenceWorkbench.applyItems(items)
    }

    private func restoreEvidenceSelection(
        afterSaving item: EvidenceItem,
        features: WorkspaceFeatureSet
    ) {
        if features.evidenceWorkbench.reviewFilter.includes(item.reviewStatus) {
            features.evidenceWorkbench.selectedItemID = item.id
        } else {
            features.evidenceWorkbench.normalizeSelection()
        }
    }

    private func evidenceCorpusMetadata(
        features: WorkspaceFeatureSet,
        fallbackSet: ConcordanceSavedSet?
    ) -> (id: String, name: String)? {
        if let corpus = currentEvidenceScopeCorpus(features: features) {
            return (corpus.id, corpus.name)
        }
        if let fallbackSet {
            return (fallbackSet.corpusID, fallbackSet.corpusName)
        }
        guard let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID else {
            return nil
        }
        let corpusName = features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })?.name
            ?? wordZText("未命名语料", "Untitled Corpus", mode: .system)
        return (corpusID, corpusName)
    }

    private func loadedKWICSavedSet(features: WorkspaceFeatureSet) -> ConcordanceSavedSet? {
        guard let loadedSavedSetID = features.kwic.loadedSavedSetID else { return nil }
        return features.kwic.savedSets.first(where: { $0.id == loadedSavedSetID })
    }

    private func loadedLocatorSavedSet(features: WorkspaceFeatureSet) -> ConcordanceSavedSet? {
        guard let loadedSavedSetID = features.locator.loadedSavedSetID else { return nil }
        return features.locator.savedSets.first(where: { $0.id == loadedSavedSetID })
    }

    private func matchingSavedSetRow(
        for row: KWICSceneRow,
        in set: ConcordanceSavedSet?
    ) -> ConcordanceSavedSetRow? {
        guard let set else { return nil }
        if let directMatch = set.rows.first(where: { $0.id == row.id }) {
            return directMatch
        }
        return set.rows.first {
            $0.sentenceId == row.sentenceId && $0.sentenceTokenIndex == row.sentenceTokenIndex
        }
    }

    private func matchingSavedSetRow(
        for row: LocatorSceneRow,
        in set: ConcordanceSavedSet?
    ) -> ConcordanceSavedSetRow? {
        guard let set else { return nil }
        return set.rows.first {
            $0.sentenceId == row.sentenceId &&
                ($0.sentenceTokenIndex == row.sourceCandidate.nodeIndex || $0.keyword == row.nodeWord)
        } ?? set.rows.first(where: { $0.sentenceId == row.sentenceId })
    }

    private func normalizedEvidenceText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? value : trimmed
    }

    private func joinedEvidenceSentence(left: String, keyword: String, right: String) -> String {
        [left, keyword, right]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func currentEvidenceScopeCorpus(features: WorkspaceFeatureSet) -> LibraryCorpusItem? {
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID else { return nil }
        return features.sidebar.librarySnapshot.corpora.first(where: { $0.id == corpusID })
    }
}
