import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleCompareAction(_ action: ComparePageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runCompare() }
        case .openKWIC:
            launch { await self.workspace.openCompareKWIC() }
        case .openCollocate:
            launch { await self.workspace.openCompareCollocate() }
        case .openSentiment:
            launch { await self.workspace.openCompareSentiment() }
        case .openSentimentExemplar(let rowID):
            launch { await self.workspace.openCompareSentiment(preferredRowID: rowID) }
        case .openSentimentSourceReader(let rowID):
            launch { await self.workspace.openCompareSentiment(preferredRowID: rowID, openSourceReaderAfterSelection: true) }
        case .openTopics:
            launch { await self.workspace.openCompareTopics() }
        case .saveCorpusSet:
            launch { await self.workspace.saveCompareCorpusSet(preferredWindowRoute: self.preferredWindowRoute) }
        case .analyzeInKeywordSuite:
            workspace.analyzeCompareSelectionInKeywordSuite()
        case .changeReferenceCorpus, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage, .toggleCorpusSelection:
            syncResult(.compare) { workspace.compare.handle(action) }
        case .copyCurrent(_):
            launch { await self.workspace.flowCoordinator.copyCompareReading(currentOnly: true, features: self.workspace.features) }
        case .copyVisible(_):
            launch { await self.workspace.flowCoordinator.copyCompareReading(currentOnly: false, features: self.workspace.features) }
        case .copyMethodSummary:
            launch { await self.workspace.flowCoordinator.copyCompareMethodSummary(features: self.workspace.features) }
        case .exportCurrent(_):
            launch {
                await self.workspace.flowCoordinator.exportCompareReading(
                    currentOnly: true,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        case .exportVisible(_):
            launch {
                await self.workspace.flowCoordinator.exportCompareReading(
                    currentOnly: false,
                    features: self.workspace.features,
                    preferredRoute: self.preferredWindowRoute
                )
            }
        }
    }
}
