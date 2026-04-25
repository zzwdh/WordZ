import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func refreshShellAvailability(
        using graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) {
        let hasPreviewableCurrent = hasPreviewableCurrentContent(in: graph, selectedTab: selectedTab)
        let exportableCurrent = hasExportableCurrentContent(in: graph, selectedTab: selectedTab)
        let runSentimentEnabled = sentiment.canRun(
            hasOpenedCorpus: sidebar.selectedCorpusID != nil,
            hasKWICRows: kwic.scene?.rows.isEmpty == false,
            hasTopicRows: topics.canAnalyzeVisibleTopicsInSentiment
        )
        shell.updateSelectionAvailability(
            hasSelection: sidebar.selectedCorpusID != nil,
            hasSourceReaderContext: canOpenSourceReaderCurrentContent,
            hasPreviewableCorpus: hasPreviewableCurrent,
            corpusCount: sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: kwic.primaryLocatorSource != nil,
            hasExportableContent: exportableCurrent,
            runSentimentEnabled: runSentimentEnabled
        )
        sidebar.applyWorkflowState(
            activeAnalysisTab: selectedTab,
            targetCorpusID: sidebarTargetCorpusID,
            referenceCorpusID: sidebarReferenceCorpusID,
            referenceSummaryOverride: sidebarReferenceSummaryOverride,
            referenceDetailOverride: sidebarReferenceDetailOverride,
            keywordEnabledOverride: selectedTab == .keyword ? keyword.workflowKeywordEnabled : nil,
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
        switch selectedTab {
        case .stats:
            return graph.stats
        case .word:
            return graph.word
        case .tokenize:
            return graph.tokenize
        case .topics:
            return graph.topics
        case .compare:
            return graph.compare
        case .sentiment:
            return graph.sentiment
        case .keyword:
            return graph.keyword
        case .chiSquare:
            return graph.chiSquare
        case .plot:
            return graph.plot
        case .ngram:
            return graph.ngram
        case .cluster:
            return graph.cluster
        case .kwic:
            return graph.kwic
        case .collocate:
            return graph.collocate
        case .locator:
            return graph.locator
        case .library, .settings:
            return nil
        }
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
