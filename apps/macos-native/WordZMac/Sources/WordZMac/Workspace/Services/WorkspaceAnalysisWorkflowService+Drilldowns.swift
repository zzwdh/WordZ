import Foundation
import WordZShared

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func preparePlotKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard !features.plot.normalizedQuery.isEmpty else {
            features.sidebar.setError(wordZText("请输入 Plot 检索词。", "Enter a Plot query first.", mode: .system))
            return false
        }
        guard let row = features.plot.selectedSceneRow else {
            features.sidebar.setError(wordZText("请先选择一条 Plot 结果。", "Select a Plot row first.", mode: .system))
            return false
        }
        guard features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == row.corpusId }) else {
            features.sidebar.setError(wordZText("当前 Plot 结果没有可用的语料上下文。", "The current Plot row has no usable corpus context.", mode: .system))
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                row.corpusId,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = features.plot.normalizedQuery
        features.kwic.searchOptions = features.plot.searchOptions
        if let marker = features.plot.selectedSceneMarker {
            features.kwic.selectedRowID = "\(marker.sentenceId)-\(marker.tokenIndex)"
        } else {
            features.kwic.selectedRowID = nil
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    func prepareClusterKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = features.cluster.selectedSceneRow else {
            features.sidebar.setError(wordZText("请先选择一条 Cluster 结果。", "Select a cluster row first.", mode: .system))
            return false
        }
        guard let corpusID = features.sidebar.selectedCorpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError(wordZText("当前 Cluster 结果没有可用的语料范围。", "The current cluster result has no usable corpus context.", mode: .system))
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = row.phrase
        features.kwic.searchOptions = SearchOptionsState(
            words: true,
            caseSensitive: features.cluster.caseSensitive,
            regex: false,
            matchMode: .phraseExact
        )
        if features.kwic.leftWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.leftWindow = "5"
        }
        if features.kwic.rightWindow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            features.kwic.rightWindow = "5"
        }
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    func prepareCompareDrilldown(
        target: CompareDrilldownTarget,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = selectedCompareResultRow(features: features) else {
            features.sidebar.setError("请先选择一条 Compare 结果。")
            return false
        }

        if target == .sentiment {
            features.compare.applySentimentDrilldownContext(
                CompareSentimentDrilldownContext(
                    focusTerm: row.word,
                    targetCorpora: features.compare.selectedTargetCorpusItems(),
                    referenceCorpora: features.compare.selectedReferenceCorpusItems()
                )
            )
            features.sentiment.source = .corpusCompare
            features.sentiment.unit = .sentence
            features.sentiment.contextBasis = .fullSentenceWhenAvailable
            features.sentiment.selectedCorpusIDs = Set(features.compare.selectedCorpusIDsSnapshot)
            features.sentiment.selectedReferenceCorpusID = features.compare.selectedReferenceCorpusIDSnapshot
            features.sentiment.rowFilterQuery = row.word
            features.sentiment.labelFilter = nil
            features.shell.selectedTab = .sentiment
            markWorkspaceEdited(features)
            return true
        }

        guard let resolvedCorpus = resolveCompareDrilldownCorpus(for: row, features: features),
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == resolvedCorpus.corpusId }) else {
            features.sidebar.setError("当前 Compare 结果没有可用的语料上下文。")
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                resolvedCorpus.corpusId,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        switch target {
        case .kwic:
            features.kwic.keyword = row.word
            features.shell.selectedTab = .kwic
        case .collocate:
            features.collocate.keyword = row.word
            features.shell.selectedTab = .collocate
        case .sentiment, .topics:
            break
        }
        markWorkspaceEdited(features)
        return true
    }

    func prepareCollocateKWIC(
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async -> Bool {
        guard let row = features.collocate.selectedSceneRow else {
            features.sidebar.setError("请先选择一条搭配词结果。")
            return false
        }
        let corpusID = features.sidebar.selectedCorpusID ?? sessionStore.openedCorpusSourceID
        guard let corpusID,
              features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == corpusID }) else {
            features.sidebar.setError("当前搭配词结果没有可用的语料范围。")
            return false
        }

        do {
            try await prepareDrilldownCorpusSelection(
                corpusID,
                features: features,
                prepareCorpusSelectionChange: prepareCorpusSelectionChange,
                syncFeatureContexts: syncFeatureContexts
            )
        } catch {
            features.sidebar.setError(error.localizedDescription)
            return false
        }

        features.kwic.keyword = row.word
        features.shell.selectedTab = .kwic
        markWorkspaceEdited(features)
        return true
    }

    func prepareDrilldownCorpusSelection(
        _ corpusID: String,
        features: WorkspaceFeatureSet,
        prepareCorpusSelectionChange: @escaping @MainActor (WorkspaceFeatureSet) -> Void,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async throws {
        features.sidebar.setSelectedCorpusID(corpusID, notifySelectionChange: false)
        features.library.selectCorpus(corpusID)
        prepareCorpusSelectionChange(features)
        _ = try await ensureOpenedCorpus(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        features.sidebar.clearError()
    }
}
