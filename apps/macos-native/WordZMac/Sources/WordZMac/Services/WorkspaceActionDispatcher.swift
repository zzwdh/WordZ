import Foundation

@MainActor
final class WorkspaceActionDispatcher: ObservableObject {
    private unowned let workspace: MainWorkspaceViewModel

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
    }

    func handleToolbarAction(_ action: WorkspaceToolbarAction) {
        switch action {
        case .refresh:
            Task { await workspace.refreshAll() }
        case .showLibrary:
            workspace.showLibrary()
        case .openSelected:
            Task { await workspace.openSelectedCorpus() }
        case .runStats:
            Task { await workspace.runStats() }
        case .runWord:
            Task { await workspace.runWord() }
        case .runCompare:
            Task { await workspace.runCompare() }
        case .runChiSquare:
            Task { await workspace.runChiSquare() }
        case .runNgram:
            Task { await workspace.runNgram() }
        case .runWordCloud:
            Task { await workspace.runWordCloud() }
        case .runKWIC:
            Task { await workspace.runKWIC() }
        case .runCollocate:
            Task { await workspace.runCollocate() }
        case .runLocator:
            Task { await workspace.runLocator() }
        case .exportCurrent:
            Task { await workspace.exportCurrent() }
        }
    }

    func handleSidebarAction(_ action: SidebarAction) {
        switch action {
        case .refresh:
            Task { await workspace.refreshLibraryManagement() }
        case .openSelected:
            Task { await workspace.openSelectedCorpus() }
        }
    }

    func handleStatsAction(_ action: StatsPageAction) {
        switch action {
        case .run:
            Task { await workspace.runStats() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            workspace.stats.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleCompareAction(_ action: ComparePageAction) {
        switch action {
        case .run:
            Task { await workspace.runCompare() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage, .toggleCorpusSelection:
            workspace.compare.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleWordAction(_ action: WordPageAction) {
        switch action {
        case .run:
            Task { await workspace.runWord() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            workspace.word.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleChiSquareAction(_ action: ChiSquarePageAction) {
        switch action {
        case .run:
            Task { await workspace.runChiSquare() }
        case .reset:
            workspace.chiSquare.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleKWICAction(_ action: KWICPageAction) {
        switch action {
        case .run:
            Task { await workspace.runKWIC() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            workspace.kwic.handle(action)
            workspace.syncLocatorSourceFromKWIC()
            workspace.syncSceneGraph()
        case .activateRow(let rowID):
            workspace.kwic.handle(.activateRow(rowID))
            workspace.syncLocatorSourceFromKWIC()
            workspace.syncSceneGraph()
            Task { await workspace.runLocator() }
        }
    }

    func handleNgramAction(_ action: NgramPageAction) {
        switch action {
        case .run:
            Task { await workspace.runNgram() }
        case .changeSort, .sortByColumn, .changePageSize, .changeSize, .toggleColumn, .previousPage, .nextPage:
            workspace.ngram.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleWordCloudAction(_ action: WordCloudPageAction) {
        switch action {
        case .run:
            Task { await workspace.runWordCloud() }
        case .changeLimit, .toggleColumn:
            workspace.wordCloud.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleCollocateAction(_ action: CollocatePageAction) {
        switch action {
        case .run:
            Task { await workspace.runCollocate() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            workspace.collocate.handle(action)
            workspace.syncSceneGraph()
        }
    }

    func handleLocatorAction(_ action: LocatorPageAction) {
        switch action {
        case .run:
            Task { await workspace.runLocator() }
        case .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            workspace.locator.handle(action)
            workspace.syncSceneGraph()
        case .activateRow(let rowID):
            workspace.locator.handle(.activateRow(rowID))
            workspace.syncSceneGraph()
            Task { await workspace.runLocator() }
        }
    }

    func handleSettingsAction(_ action: SettingsPaneAction) {
        switch action {
        case .save:
            Task { await workspace.saveSettings() }
        case .checkForUpdatesNow:
            Task { await workspace.checkForUpdatesNow() }
        case .downloadUpdate:
            Task { await workspace.downloadLatestUpdate() }
        case .installDownloadedUpdate:
            Task { await workspace.installDownloadedUpdate() }
        case .revealDownloadedUpdate:
            Task { await workspace.revealDownloadedUpdate() }
        case .showTaskCenter:
            NativeAppCommandCenter.post(.showTaskCenterWindow)
        case .showHelpWindow:
            NativeAppCommandCenter.post(.showHelpWindow)
        case .showAboutWindow:
            NativeAppCommandCenter.post(.showAboutWindow)
        case .showReleaseNotesWindow:
            NativeAppCommandCenter.post(.showReleaseNotesWindow)
        case .exportDiagnostics:
            Task { await workspace.exportDiagnostics() }
        case .openUserDataDirectory:
            Task { await workspace.openUserDataDirectory() }
        case .openFeedback:
            Task { await workspace.openFeedback() }
        case .openProjectHome:
            Task { await workspace.openProjectHome() }
        case .openReleaseNotes:
            Task { await workspace.openReleaseNotes() }
        case .clearRecentDocuments:
            Task { await workspace.clearRecentDocuments() }
        case .reopenRecent(let corpusID):
            Task { await workspace.openRecentDocument(corpusID) }
        }
    }

    func handleWelcomeAction(_ action: WelcomeAction) {
        switch action {
        case .dismiss:
            workspace.dismissWelcome()
        case .openSelection:
            workspace.dismissWelcome()
            Task { await workspace.openSelectedCorpus() }
        case .showLibrary:
            workspace.dismissWelcome()
            workspace.showLibrary()
        case .openRecent(let corpusID):
            Task { await workspace.openRecentDocument(corpusID) }
        case .openReleaseNotes:
            NativeAppCommandCenter.post(.showReleaseNotesWindow)
        case .openFeedback:
            Task { await workspace.openFeedback() }
        }
    }

    func handleLibraryAction(_ action: LibraryManagementAction) {
        switch action {
        case .selectFolder(let folderID):
            workspace.library.selectFolder(folderID)
            if workspace.sidebar.selectedCorpusID != workspace.library.selectedCorpusID {
                workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
            }
            workspace.syncSceneGraph()
        case .selectCorpus(let corpusID):
            workspace.library.selectCorpus(corpusID)
            workspace.sidebar.selectedCorpusID = corpusID
            workspace.syncSceneGraph()
        case .selectRecycleEntry(let recycleEntryID):
            workspace.library.selectRecycleEntry(recycleEntryID)
            workspace.sidebar.selectedCorpusID = nil
            workspace.syncSceneGraph()
        case .openSelectedCorpus:
            if let selectedCorpusID = workspace.library.selectedCorpusID {
                workspace.sidebar.selectedCorpusID = selectedCorpusID
            }
            workspace.syncSceneGraph()
            Task { await workspace.openSelectedCorpus() }
        default:
            Task { await workspace.handleLibraryAction(action) }
        }
    }
}
