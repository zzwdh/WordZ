import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleKeywordAction(_ action: KeywordPageAction) {
        if action.routesThroughViewModel {
            syncResult(.keyword) { workspace.keyword.handle(action) }
            return
        }

        handleKeywordWorkflowAction(action)
    }

    private func handleKeywordWorkflowAction(_ action: KeywordPageAction) {
        switch action {
        case .run:
            launch { await self.workspace.runKeyword() }
        case .saveCurrentList:
            launch { await self.workspace.saveKeywordCurrentList() }
        case .refreshSavedLists:
            launch { await self.workspace.refreshKeywordSavedLists() }
        case .deleteSavedList(let listID):
            launch { await self.workspace.deleteKeywordSavedList(listID) }
        case .importSavedListsJSON:
            launch { await self.workspace.importKeywordSavedListsJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportSelectedSavedListJSON:
            launch { await self.workspace.exportSelectedKeywordSavedListJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportAllSavedListsJSON:
            launch { await self.workspace.exportAllKeywordSavedListsJSON(preferredWindowRoute: self.preferredWindowRoute) }
        case .importReferenceWordList:
            launch { await self.workspace.importKeywordReferenceWordList(preferredWindowRoute: self.preferredWindowRoute) }
        case .exportRowContext:
            launch { await self.workspace.exportKeywordRowContext(preferredWindowRoute: self.preferredWindowRoute) }
        case .openFocusKWIC:
            launch { await self.workspace.openKeywordKWIC(scope: .focus) }
        case .openReferenceKWIC:
            launch { await self.workspace.openKeywordKWIC(scope: .reference) }
        case .openCompareDistribution:
            workspace.openCompareDistributionFromKeyword()
        case .changeTargetCorpus, .changeReferenceCorpus, .changeStatistic, .changeTab, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            assertionFailure("Keyword scene actions should be handled through the view model sync path.")
        }
    }
}
