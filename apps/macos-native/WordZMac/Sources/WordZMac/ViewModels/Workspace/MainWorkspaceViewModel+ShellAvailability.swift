import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func refreshShellAvailability(
        using graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) {
        let hasPreviewableCurrent = hasPreviewableCurrentContent(in: graph, selectedTab: selectedTab)
        let exportableCurrent = hasExportableCurrentContent(in: graph, selectedTab: selectedTab)
        let currentArtifact = currentResultArtifact(in: graph, selectedTab: selectedTab)
        let copyableCurrent = currentArtifact?.supports(.copy) == true
        let hasSelectedAnalysisSource = sidebar.selectedCorpusID != nil || sidebar.selectedCorpusSetID != nil
        let runSentimentEnabled = sentiment.canRun(
            hasOpenedCorpus: hasSelectedAnalysisSource,
            hasKWICRows: kwic.scene?.rows.isEmpty == false,
            hasTopicRows: topics.canAnalyzeVisibleTopicsInSentiment
        )
        shell.updateSelectionAvailability(
            hasSelection: hasSelectedAnalysisSource,
            hasSourceReaderContext: currentArtifact?.supports(.openSourceReader) == true,
            hasPreviewableCorpus: hasPreviewableCurrent,
            corpusCount: sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: kwic.primaryLocatorSource != nil,
            hasCopyableContent: copyableCurrent,
            hasExportableContent: exportableCurrent,
            runSentimentEnabled: runSentimentEnabled
        )
        sidebar.applyWorkflowState(
            activeAnalysisTab: selectedTab,
            targetCorpusID: sidebarTargetCorpusID,
            referenceCorpusID: sidebarReferenceCorpusID,
            referenceSummaryOverride: sidebarReferenceSummaryOverride,
            referenceDetailOverride: sidebarReferenceDetailOverride,
            resultsSummary: currentSidebarResultsSummary(
                using: graph,
                selectedTab: selectedTab,
                exportableCurrent: exportableCurrent
            )
        )
    }

    var currentResultSceneNode: WorkspaceResultSceneNode? {
        currentResultSceneNode(in: sceneGraph, selectedTab: selectedTab)
    }

    func currentResultSceneNode(
        in graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) -> WorkspaceResultSceneNode? {
        graph.resultNode(for: selectedTab)
    }

    func currentSidebarResultsSummary(
        using graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab,
        exportableCurrent: Bool
    ) -> WorkspaceSidebarResultsSceneModel? {
        guard exportableCurrent,
              let node = currentResultSceneNode(in: graph, selectedTab: selectedTab)
        else { return nil }
        return WorkspaceSidebarResultsSceneModel(
            title: node.title,
            subtitle: node.status,
            exportTitle: t("导出当前结果", "Export Current Result")
        )
    }
}
