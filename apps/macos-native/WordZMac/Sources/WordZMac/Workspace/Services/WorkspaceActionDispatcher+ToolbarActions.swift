import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleToolbarAction(_ action: WorkspaceToolbarAction) {
        switch action {
        case .refresh:
            launch { await self.workspace.refreshAll() }
        case .showLibrary:
            NativeAppCommandCenter.post(.showLibrary)
        case .openSelected:
            launch { await self.workspace.openSelectedCorpus() }
        case .previewCurrentCorpus:
            launch { await self.workspace.quickLookCurrentCorpus() }
        case .shareCurrentContent:
            launch { await self.workspace.shareCurrentContent() }
        case .runStats:
            launch { await self.workspace.runStats() }
        case .runWord:
            launch { await self.workspace.runWord() }
        case .runTokenize:
            launch { await self.workspace.runTokenize() }
        case .runTopics:
            launch { await self.workspace.runTopics() }
        case .runCompare:
            launch { await self.workspace.runCompare() }
        case .runKeyword:
            launch { await self.workspace.runKeyword() }
        case .runChiSquare:
            launch { await self.workspace.runChiSquare() }
        case .runNgram:
            launch { await self.workspace.runNgram() }
        case .runKWIC:
            launch { await self.workspace.runKWIC() }
        case .runCollocate:
            launch { await self.workspace.runCollocate() }
        case .runLocator:
            launch { await self.workspace.runLocator() }
        case .exportCurrent:
            launch { await self.workspace.exportCurrent(preferredWindowRoute: self.preferredWindowRoute) }
        }
    }
}
