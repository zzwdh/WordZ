import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func refreshShellAvailability(
        using graph: WorkspaceSceneGraph,
        selectedTab: WorkspaceDetailTab
    ) {
        let currentContentTarget = currentContentTarget(in: graph, selectedTab: selectedTab)
        let exportableCurrent = currentExportSnapshot(in: graph, selectedTab: selectedTab) != nil
        shell.updateSelectionAvailability(
            hasSelection: sidebar.selectedCorpusID != nil,
            hasPreviewableCorpus: currentContentTarget != nil,
            corpusCount: sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: kwic.primaryLocatorSource != nil,
            hasExportableContent: exportableCurrent
        )
        sidebar.applyWorkflowState(
            activeAnalysisTab: selectedTab,
            targetCorpusID: sidebarTargetCorpusID,
            referenceCorpusID: keyword.referenceCorpusIDSnapshot.isEmpty ? nil : keyword.referenceCorpusIDSnapshot,
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
        case .keyword:
            return graph.keyword
        case .chiSquare:
            return graph.chiSquare
        case .ngram:
            return graph.ngram
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
