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
            NativeAppCommandCenter.post(.showLibrary)
        case .openSelected:
            Task { await workspace.openSelectedCorpus() }
        case .previewCurrentCorpus:
            Task { await workspace.quickLookCurrentCorpus() }
        case .shareCurrentContent:
            Task { await workspace.shareCurrentContent() }
        case .runStats:
            Task { await workspace.runStats() }
        case .runWord:
            Task { await workspace.runWord() }
        case .runTokenize:
            Task { await workspace.runTokenize() }
        case .runTopics:
            Task { await workspace.runTopics() }
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
        case .quickLookSelected(let corpusID):
            workspace.sidebar.selectedCorpusID = corpusID
            workspace.library.selectCorpus(corpusID)
            workspace.syncSceneGraph(source: .librarySelection)
            Task { await workspace.quickLookSelectedCorpus() }
        case .showCorpusInfoSelected(let corpusID):
            workspace.sidebar.selectedCorpusID = corpusID
            workspace.library.selectCorpus(corpusID)
            workspace.syncSceneGraph(source: .librarySelection)
            NativeAppCommandCenter.post(.showLibrary)
            Task { await workspace.handleLibraryAction(.showSelectedCorpusInfo) }
        }
    }

    func handleStatsAction(_ action: StatsPageAction) {
        switch action {
        case .run:
            Task { await workspace.runStats() }
        case .changeNormalizationUnit(let unit):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: workspace.stats.metricDefinition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: workspace.stats.metricDefinition.normalizationUnit,
                    rangeMode: mode
                )
            )
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            workspace.stats.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleCompareAction(_ action: ComparePageAction) {
        switch action {
        case .run:
            Task { await workspace.runCompare() }
        case .changeReferenceCorpus, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage, .toggleCorpusSelection:
            workspace.compare.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleWordAction(_ action: WordPageAction) {
        switch action {
        case .run:
            Task { await workspace.runWord() }
        case .changeNormalizationUnit(let unit):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: unit,
                    rangeMode: workspace.word.metricDefinition.rangeMode
                )
            )
        case .changeRangeMode(let mode):
            workspace.updateFrequencyMetricDefinition(
                FrequencyMetricDefinition(
                    normalizationUnit: workspace.word.metricDefinition.normalizationUnit,
                    rangeMode: mode
                )
            )
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage:
            workspace.word.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleTokenizeAction(_ action: TokenizePageAction) {
        switch action {
        case .run:
            Task { await workspace.runTokenize() }
        case .exportText:
            Task { await workspace.exportTokenizedText() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            workspace.tokenize.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleTopicsAction(_ action: TopicsPageAction) {
        switch action {
        case .run:
            Task { await workspace.runTopics() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectCluster, .previousPage, .nextPage:
            workspace.topics.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        case .exportSummary:
            Task { await workspace.exportTopicsSummary() }
        case .exportSegments:
            Task { await workspace.exportTopicsSegments() }
        }
    }

    func handleChiSquareAction(_ action: ChiSquarePageAction) {
        switch action {
        case .run:
            Task { await workspace.runChiSquare() }
        case .reset:
            workspace.chiSquare.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleKWICAction(_ action: KWICPageAction) {
        switch action {
        case .run:
            Task { await workspace.runKWIC() }
        case .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            workspace.kwic.handle(action)
            workspace.syncLocatorSourceFromKWIC()
            workspace.syncSceneGraph(source: .resultContent)
        case .activateRow(let rowID):
            workspace.kwic.handle(.activateRow(rowID))
            workspace.syncLocatorSourceFromKWIC()
            workspace.syncSceneGraph(source: .resultContent)
            Task { await workspace.runLocator() }
        }
    }

    func handleNgramAction(_ action: NgramPageAction) {
        switch action {
        case .run:
            Task { await workspace.runNgram() }
        case .changeSort, .sortByColumn, .changePageSize, .changeSize, .toggleColumn, .previousPage, .nextPage:
            workspace.ngram.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleWordCloudAction(_ action: WordCloudPageAction) {
        switch action {
        case .run:
            Task { await workspace.runWordCloud() }
        case .changeLimit, .toggleColumn:
            workspace.wordCloud.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleCollocateAction(_ action: CollocatePageAction) {
        switch action {
        case .run:
            Task { await workspace.runCollocate() }
        case .applyPreset, .changeFocusMetric, .changeSort, .sortByColumn, .changePageSize, .toggleColumn, .selectRow, .previousPage, .nextPage:
            workspace.collocate.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        }
    }

    func handleLocatorAction(_ action: LocatorPageAction) {
        switch action {
        case .run:
            Task { await workspace.runLocator() }
        case .changePageSize, .toggleColumn, .previousPage, .nextPage, .selectRow:
            workspace.locator.handle(action)
            workspace.syncSceneGraph(source: .resultContent)
        case .activateRow(let rowID):
            workspace.locator.handle(.activateRow(rowID))
            workspace.syncSceneGraph(source: .resultContent)
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
            NativeAppCommandCenter.post(.showLibrary)
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
            workspace.syncSceneGraph(source: .librarySelection)
        case .selectCorpus(let corpusID):
            workspace.library.selectCorpus(corpusID)
            workspace.sidebar.selectedCorpusID = corpusID
            workspace.syncSceneGraph(source: .librarySelection)
        case .selectRecycleEntry(let recycleEntryID):
            workspace.library.selectRecycleEntry(recycleEntryID)
            workspace.sidebar.selectedCorpusID = nil
            workspace.syncSceneGraph(source: .librarySelection)
        case .openSelectedCorpus:
            if let selectedCorpusID = workspace.library.selectedCorpusID {
                workspace.sidebar.selectedCorpusID = selectedCorpusID
            }
            workspace.syncSceneGraph(source: .librarySelection)
            Task { await workspace.openSelectedCorpus() }
        case .quickLookSelectedCorpus:
            Task { await workspace.quickLookSelectedCorpus() }
        case .editSelectedCorpusMetadata:
            if let selectedCorpus = workspace.library.selectedCorpus ?? workspace.sidebar.selectedCorpus {
                workspace.library.presentMetadataEditor(for: selectedCorpus)
            }
        default:
            Task { await workspace.handleLibraryAction(action) }
        }
    }
}
