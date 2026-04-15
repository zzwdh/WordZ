import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class ViewModelsTests: XCTestCase {
    func testStatsPageViewModelSupportsSortingPagingAndColumnToggles() {
        let viewModel = StatsPageViewModel()
        viewModel.apply(makeStatsResult(rowCount: 120))

        XCTAssertEqual(viewModel.scene?.rows.count, 100)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / 120")
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.rank) ?? true)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.word) ?? false)

        viewModel.handle(.nextPage)
        XCTAssertEqual(viewModel.scene?.rows.count, 20)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "101-120 / 120")

        viewModel.handle(.changeSort(.alphabeticalAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "word-0")
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / 120")

        viewModel.handle(.toggleColumn(.count))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.count) ?? true)

        viewModel.handle(.toggleColumn(.count))
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.count) ?? false)
    }

    func testStatsPageViewModelFallsBackFromAllPageSizeForLargeResults() {
        let viewModel = StatsPageViewModel()
        let expectation = expectation(description: "stats fallback scene updated")
        viewModel.apply(makeStatsResult(rowCount: 1_200))

        viewModel.handle(.changePageSize(.all))

        XCTAssertEqual(viewModel.pageSize, .twoHundredFifty)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .twoHundredFifty)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testComparePageViewModelTracksSelectionAndColumns() {
        let viewModel = ComparePageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        XCTAssertEqual(viewModel.selectedCorpusCount, 2)

        viewModel.apply(makeCompareResult())
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.distribution) ?? true)
        viewModel.handle(.toggleColumn(.distribution))
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.distribution) ?? false)
        XCTAssertEqual(viewModel.selectedSceneRow?.word, "alpha")
        viewModel.handle(.selectRow("beta"))
        XCTAssertEqual(viewModel.selectedSceneRow?.word, "beta")

        viewModel.handle(.changeSort(.alphabeticalAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "alpha")
    }

    func testComparePageViewModelRestoresAndAppliesFixedReferenceCorpus() {
        let viewModel = ComparePageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        viewModel.apply(makeCompareResult())

        viewModel.handle(.changeReferenceCorpus("corpus-1"))
        XCTAssertEqual(viewModel.selectedReferenceOptionID, "corpus-1")
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "beta")

        viewModel.apply(makeWorkspaceSnapshot(currentTab: "compare", compareReferenceCorpusID: "corpus-2"))
        XCTAssertEqual(viewModel.selectedReferenceOptionID, "corpus-2")
    }

    func testComparePageViewModelRestoresSelectedCorpusSetFromSnapshot() {
        let viewModel = ComparePageViewModel()
        let librarySnapshot = LibrarySnapshot(
            folders: [LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])],
            corpora: [
                LibraryCorpusItem(json: ["id": "corpus-1", "name": "Corpus 1", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"]),
                LibraryCorpusItem(json: ["id": "corpus-2", "name": "Corpus 2", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"]),
                LibraryCorpusItem(json: ["id": "corpus-3", "name": "Corpus 3", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"])
            ]
        )
        viewModel.syncLibrarySnapshot(librarySnapshot)

        viewModel.apply(
            makeWorkspaceSnapshot(
                currentTab: "compare",
                compareReferenceCorpusID: "corpus-3",
                compareSelectedCorpusIDs: ["corpus-1", "corpus-3"]
            )
        )

        XCTAssertEqual(Set(viewModel.selectedCorpusIDsSnapshot), Set(["corpus-1", "corpus-3"]))
        XCTAssertEqual(viewModel.selectedCorpusCount, 2)
        XCTAssertEqual(viewModel.selectedReferenceOptionID, "corpus-3")
    }

    func testComparePageViewModelChangeReferenceCorpusActionTriggersSingleInputCallback() {
        let viewModel = ComparePageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        viewModel.apply(makeCompareResult())
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.handle(.changeReferenceCorpus("corpus-1"))

        XCTAssertEqual(inputChangeCount, 1)
        XCTAssertEqual(viewModel.selectedReferenceOptionID, "corpus-1")
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "beta")
    }

    func testComparePageViewModelToggleCorpusSelectionTriggersSingleInputCallbackAndClearsResult() {
        let viewModel = ComparePageViewModel()
        let librarySnapshot = LibrarySnapshot(
            folders: [LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])],
            corpora: [
                LibraryCorpusItem(json: ["id": "corpus-1", "name": "Corpus 1", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"]),
                LibraryCorpusItem(json: ["id": "corpus-2", "name": "Corpus 2", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"]),
                LibraryCorpusItem(json: ["id": "corpus-3", "name": "Corpus 3", "folderId": "folder-1", "folderName": "Default", "sourceType": "txt"])
            ]
        )
        viewModel.syncLibrarySnapshot(librarySnapshot)
        viewModel.apply(makeCompareResult())
        viewModel.selectedCorpusIDs = ["corpus-1", "corpus-2", "corpus-3"]
        viewModel.selectionItems = librarySnapshot.corpora.map {
            CompareSelectableCorpusSceneItem(
                id: $0.id,
                title: $0.name,
                subtitle: $0.folderName,
                isSelected: true
            )
        }
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.handle(.toggleCorpusSelection("corpus-3"))

        XCTAssertEqual(inputChangeCount, 1)
        XCTAssertEqual(viewModel.selectedCorpusCount, 2)
        XCTAssertNil(viewModel.result)
        XCTAssertNil(viewModel.scene)
    }

    func testSentimentPageViewModelDefaultsAndRestoresSnapshotState() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        XCTAssertEqual(viewModel.source, .openedCorpus)
        XCTAssertEqual(viewModel.unit, .sentence)
        XCTAssertEqual(viewModel.visibleColumns, SentimentPageViewModel.defaultVisibleColumns)

        viewModel.handle(.changeSource(.kwicVisible))
        XCTAssertEqual(viewModel.unit, .concordanceLine)

        viewModel.apply(makeSentimentResult())
        viewModel.apply(
            makeWorkspaceSnapshot(
                currentTab: WorkspaceDetailTab.sentiment.snapshotValue,
                sentimentSource: .corpusCompare,
                sentimentUnit: .document,
                sentimentContextBasis: .fullSentenceWhenAvailable,
                sentimentChartKind: .trendLine,
                sentimentThresholdPreset: .balanced,
                sentimentDecisionThreshold: 0.25,
                sentimentMinimumEvidence: 0.6,
                sentimentNeutralBias: 1.0,
                sentimentRowFilterQuery: "good",
                sentimentLabelFilter: .positive,
                sentimentSelectedCorpusIDs: ["corpus-1"],
                sentimentReferenceCorpusID: "corpus-2"
            )
        )

        XCTAssertEqual(viewModel.source, .corpusCompare)
        XCTAssertEqual(viewModel.unit, .document)
        XCTAssertEqual(viewModel.contextBasis, .fullSentenceWhenAvailable)
        XCTAssertEqual(viewModel.chartKind, .trendLine)
        XCTAssertEqual(viewModel.thresholdPreset, .balanced)
        XCTAssertEqual(viewModel.labelFilter, .positive)
        XCTAssertEqual(viewModel.selectedReferenceCorpusID, "corpus-2")
        XCTAssertEqual(viewModel.selectedCorpusIDs, Set(["corpus-1"]))
        XCTAssertEqual(viewModel.scene?.filteredRows, 1)
    }

    func testKeywordPageViewModelKeepsReferenceOptionalUntilExplicitlyChosen() {
        let viewModel = KeywordPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        XCTAssertEqual(viewModel.targetCorpusIDSnapshot, "corpus-1")
        XCTAssertEqual(viewModel.referenceCorpusIDSnapshot, "")
        XCTAssertFalse(viewModel.canRun)
    }

    func testKeywordPageViewModelRestoresSuiteConfigurationFromSnapshot() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let configuration = KeywordSuiteConfiguration(
            focusSelection: KeywordTargetSelection(
                kind: .namedCorpusSet,
                corpusIDs: [],
                corpusSetID: "set-1"
            ),
            referenceSource: KeywordReferenceSource(
                kind: .importedWordList,
                corpusID: "",
                corpusSetID: "",
                importedListText: "alpha\t2\nbeta\t1",
                importedListSourceName: "teaching-list.tsv",
                importedListImportedAt: "2026-04-12T09:30:00Z"
            ),
            unit: .lemmaPreferred,
            direction: .both,
            statistic: .chiSquare,
            thresholds: KeywordThresholds(
                minFocusFreq: 4,
                minReferenceFreq: 1,
                minCombinedFreq: 5,
                maxPValue: 0.05,
                minAbsLogRatio: 0.4
            ),
            tokenFilters: KeywordTokenFilterState(
                languagePreset: .latinFocused,
                lemmaStrategy: .lemmaPreferred,
                scripts: [.latin],
                lexicalClasses: [.noun, .adjective],
                stopwordFilter: StopwordFilterState(
                    enabled: true,
                    mode: .include,
                    listText: "alpha\nbeta"
                )
            )
        )
        let viewModel = KeywordPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)

        viewModel.apply(
            makeWorkspaceSnapshot(
                currentTab: "keyword",
                keywordActiveTab: .terms,
                keywordSuiteConfiguration: configuration
            )
        )

        XCTAssertEqual(viewModel.activeTab, .terms)
        XCTAssertEqual(viewModel.focusSelectionKind, .namedCorpusSet)
        XCTAssertEqual(viewModel.selectedFocusCorpusSetID, "set-1")
        XCTAssertEqual(viewModel.referenceSourceKind, .importedWordList)
        XCTAssertEqual(viewModel.importedReferenceListText, "alpha\t2\nbeta\t1")
        XCTAssertEqual(viewModel.importedReferenceListSourceName, "teaching-list.tsv")
        XCTAssertEqual(viewModel.importedReferenceListImportedAt, "2026-04-12T09:30:00Z")
        XCTAssertEqual(viewModel.unit, .lemmaPreferred)
        XCTAssertEqual(viewModel.direction, .both)
        XCTAssertEqual(viewModel.statistic, .chiSquare)
        XCTAssertEqual(viewModel.languagePreset, .latinFocused)
        XCTAssertEqual(viewModel.minFocusFrequency, "4")
        XCTAssertEqual(viewModel.minReferenceFrequency, "1")
        XCTAssertEqual(viewModel.minCombinedFrequency, "5")
        XCTAssertEqual(viewModel.maxPValue, "0.05")
        XCTAssertEqual(viewModel.minAbsLogRatio, "0.4")
        XCTAssertEqual(viewModel.selectedScripts, [.latin])
        XCTAssertEqual(viewModel.selectedLexicalClasses, [.noun, .adjective])
        XCTAssertTrue(viewModel.stopwordFilter.enabled)
        XCTAssertEqual(viewModel.stopwordFilter.mode, .include)
    }

    func testKeywordPageViewModelImportedReferenceParseSummaryTracksAcceptedAndRejectedLines() {
        let viewModel = KeywordPageViewModel()

        viewModel.referenceSourceKind = .importedWordList
        viewModel.importedReferenceListText = "alpha\t2\n\nbeta\t0\nomega"

        XCTAssertEqual(viewModel.importedReferenceParseResult.totalLineCount, 4)
        XCTAssertEqual(viewModel.importedReferenceParseResult.acceptedLineCount, 2)
        XCTAssertEqual(viewModel.importedReferenceParseResult.rejectedLineCount, 2)
        XCTAssertEqual(viewModel.importedReferenceParseResult.acceptedItemCount, 2)
        XCTAssertFalse(viewModel.importedReferenceParseSummaryText.isEmpty)
    }

    func testKeywordPageViewModelBuildsSelectionSummariesAcrossPooledAndNamedModes() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = KeywordPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)

        viewModel.focusSelectionKind = .selectedCorpora
        viewModel.selectedFocusCorpusIDs = ["corpus-1", "corpus-2"]

        XCTAssertTrue(viewModel.focusSelectionSummary.contains("2"))
        XCTAssertTrue(viewModel.focusSelectionSummary.contains("Demo Corpus"))
        XCTAssertEqual(viewModel.targetCorpusIDSnapshot, "corpus-1")
        XCTAssertTrue(viewModel.canResolveFocusSelection)

        viewModel.referenceSourceKind = .namedCorpusSet
        viewModel.selectedReferenceCorpusSetID = "set-1"

        XCTAssertEqual(viewModel.referenceSelectionSummary, "教材集")
        XCTAssertEqual(viewModel.workflowReferenceSummary, "教材集")
        XCTAssertTrue(viewModel.workflowReferenceDetail.contains("2"))
        XCTAssertTrue(viewModel.canResolveReferenceSelection)
    }

    func testKeywordPageViewModelImportedReferenceWorkflowSummaryPrefersSourceName() {
        let viewModel = KeywordPageViewModel()

        viewModel.referenceSourceKind = .importedWordList
        viewModel.importedReferenceListText = "alpha\t2\nbeta\t1"
        viewModel.importedReferenceListSourceName = "teaching-list.tsv"

        XCTAssertTrue(viewModel.referenceSelectionSummary.contains("2"))
        XCTAssertEqual(viewModel.workflowReferenceSummary, "teaching-list.tsv")
        XCTAssertTrue(
            viewModel.workflowReferenceDetail.contains("2/2")
                || viewModel.workflowReferenceDetail.contains("2 items")
                || viewModel.workflowReferenceDetail.contains("2 项")
        )
    }

    func testKeywordPageViewModelNamedCorpusSetSelectionTriggersSingleInputCallback() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = KeywordPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.focusSelectionKind = .namedCorpusSet

        XCTAssertEqual(inputChangeCount, 1)
        XCTAssertEqual(viewModel.selectedFocusCorpusSetID, "set-1")
    }

    func testKeywordPageViewModelChangeTargetCorpusActionBatchesSelectionMutation() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = KeywordPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)
        viewModel.focusSelectionKind = .namedCorpusSet
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.handle(.changeTargetCorpus("corpus-2"))

        XCTAssertEqual(inputChangeCount, 1)
        XCTAssertEqual(viewModel.focusSelectionKind, .singleCorpus)
        XCTAssertEqual(viewModel.selectedFocusCorpusID, "corpus-2")
    }

    func testLibrarySidebarViewModelBuildsWorkflowSidebarWithConditionalKeywordAndResults() {
        let viewModel = LibrarySidebarViewModel()
        viewModel.applyBootstrap(makeBootstrapState())
        viewModel.selectedCorpusID = "corpus-1"

        viewModel.applyWorkflowState(
            activeAnalysisTab: .stats,
            targetCorpusID: "corpus-1",
            referenceCorpusID: nil,
            resultsSummary: nil
        )

        XCTAssertEqual(viewModel.scene.targetCorpus.summary, "Demo Corpus")
        XCTAssertEqual(
            viewModel.scene.referenceCorpus.summary,
            wordZText("可选", "Optional", mode: viewModel.languageMode)
        )
        XCTAssertFalse(viewModel.scene.analysisViews.first(where: { $0.tab == .keyword })?.isEnabled ?? true)
        XCTAssertNil(viewModel.scene.results)

        viewModel.applyWorkflowState(
            activeAnalysisTab: .keyword,
            targetCorpusID: "corpus-1",
            referenceCorpusID: "corpus-2",
            resultsSummary: WorkspaceSidebarResultsSceneModel(
                title: "Keyword",
                subtitle: "Showing 20 / 20",
                exportTitle: "Export Current Result"
            )
        )

        XCTAssertTrue(viewModel.scene.analysisViews.first(where: { $0.tab == .keyword })?.isEnabled ?? false)
        XCTAssertEqual(viewModel.scene.results?.title, "Keyword")

        viewModel.metadataSourceQuery = "教材"
        viewModel.metadataYearFromQuery = "2024"
        viewModel.metadataTagsQuery = "课堂"

        XCTAssertEqual(
            viewModel.scene.metadataFilterSummary,
            CorpusMetadataFilterState(
                sourceQuery: "教材",
                yearFrom: "2024",
                yearTo: nil,
                genreQuery: "",
                tagsQuery: "课堂"
            ).summaryText(in: viewModel.languageMode)
        )
        XCTAssertFalse(viewModel.scene.analysisViews.first(where: { $0.tab == .keyword })?.isEnabled ?? true)
    }

    func testLibrarySidebarViewModelMetadataFiltersNarrowCorpusOptions() {
        let viewModel = LibrarySidebarViewModel()
        viewModel.applyBootstrap(makeBootstrapState())
        viewModel.selectedCorpusID = "corpus-2"

        viewModel.metadataSourceQuery = "教材"

        XCTAssertEqual(viewModel.selectedCorpusID, "corpus-1")
        XCTAssertEqual(viewModel.filteredCorpusCount, 1)
        XCTAssertEqual(viewModel.scene.corpusOptions.map(\.id), ["corpus-1"])
        XCTAssertEqual(
            viewModel.scene.metadataFilterSummary,
            CorpusMetadataFilterState(
                sourceQuery: "教材",
                genreQuery: "",
                tagsQuery: ""
            ).summaryText(in: viewModel.languageMode)
        )
    }

    func testLibrarySidebarViewModelApplyingCorpusSetNarrowsOptionsAndSyncsFilters() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1"],
            "corpusNames": ["Demo Corpus"],
            "metadataFilter": [
                "sourceQuery": "教材",
                "yearQuery": "2024",
                "genreQuery": "",
                "tagsQuery": "课堂"
            ],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = LibrarySidebarViewModel()
        var callbackCount = 0
        viewModel.onMetadataFilterChange = { _ in
            callbackCount += 1
        }
        viewModel.applyBootstrap(makeBootstrapState(corpusSets: [savedSet]))
        viewModel.selectedCorpusID = "corpus-2"

        viewModel.applyCorpusSet(savedSet)

        XCTAssertEqual(viewModel.selectedCorpusSetID, "set-1")
        XCTAssertEqual(viewModel.metadataFilterState, savedSet.metadataFilterState)
        XCTAssertEqual(viewModel.metadataFilterState.yearFrom, "2024")
        XCTAssertEqual(viewModel.metadataFilterState.yearTo, "2024")
        XCTAssertEqual(viewModel.filteredCorpusCount, 1)
        XCTAssertEqual(viewModel.selectedCorpusID, "corpus-1")
        XCTAssertTrue(viewModel.scene.selectedCorpusSetSummary?.contains("教材集") ?? false)
        XCTAssertEqual(callbackCount, 1)
    }

    func testLibrarySidebarViewModelClearMetadataFiltersBatchesSingleCallback() {
        let viewModel = LibrarySidebarViewModel()
        var callbackCount = 0
        viewModel.onMetadataFilterChange = { _ in
            callbackCount += 1
        }
        viewModel.applyBootstrap(makeBootstrapState())

        viewModel.metadataSourceQuery = "教材"
        callbackCount = 0

        viewModel.clearMetadataFilters()

        XCTAssertEqual(callbackCount, 1)
        XCTAssertTrue(viewModel.metadataFilterState.isEmpty)
        XCTAssertEqual(viewModel.filteredCorpusCount, 2)
        XCTAssertNil(viewModel.scene.metadataFilterSummary)
    }

    func testLibrarySidebarViewModelLoadsRecentSourcesAndSuggestionsFromBootstrap() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教材集",
            "corpusIds": ["corpus-1"],
            "corpusNames": ["Demo Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = LibrarySidebarViewModel()
        let referenceDate = ISO8601DateFormatter().date(from: "2026-04-10T00:00:00Z")!
        viewModel.metadataSuggestionDateProvider = { referenceDate }
        viewModel.applyBootstrap(
            makeBootstrapState(
                corpusSets: [savedSet],
                uiSettings: UISettingsSnapshot(
                    showWelcomeScreen: true,
                    restoreWorkspace: true,
                    debugLogging: false,
                    recentMetadataSourceLabels: ["播客", "教材", "访谈"],
                    recentCorpusSetIDs: ["set-1"]
                )
            )
        )

        XCTAssertEqual(viewModel.recentMetadataSourceLabels, ["播客", "教材", "访谈"])
        XCTAssertEqual(viewModel.recentCorpusSetIDs, ["set-1"])
        XCTAssertEqual(viewModel.recentCorpusSets.map(\.id), ["set-1"])
        XCTAssertEqual(viewModel.metadataRecentSourceMenuLabels, ["播客"])
        XCTAssertEqual(viewModel.metadataQuickYearLabels, ["2026", "2025", "2024", "2023", "2022"])
        XCTAssertEqual(viewModel.metadataSuggestedYearLabels, ["2024", "2023"])
        XCTAssertEqual(viewModel.metadataCommonYearLabels, ["2024", "2023"])
    }

    func testLibrarySidebarViewModelYearShortcutAppliesStructuredBounds() throws {
        let viewModel = LibrarySidebarViewModel()
        let referenceDate = ISO8601DateFormatter().date(from: "2026-04-10T00:00:00Z")!
        viewModel.metadataSuggestionDateProvider = { referenceDate }
        viewModel.applyBootstrap(makeBootstrapState())

        let shortcut = try XCTUnwrap(
            viewModel.metadataYearRangeShortcuts.first(where: { $0.kind == .recentThreeYears })
        )
        viewModel.applyMetadataYearRangeShortcut(shortcut)

        XCTAssertEqual(viewModel.metadataYearFromQuery, "2024")
        XCTAssertEqual(viewModel.metadataYearToQuery, "2026")
    }

    func testChiSquarePageViewModelValidatesAndResets() throws {
        let viewModel = ChiSquarePageViewModel()
        viewModel.a = "10"
        viewModel.b = "20"
        viewModel.c = "5"
        viewModel.d = "15"

        let inputs = try viewModel.validatedInputs()
        XCTAssertEqual(inputs.0, 10)
        XCTAssertEqual(inputs.3, 15)

        viewModel.apply(makeChiSquareResult())
        XCTAssertNotNil(viewModel.scene)
        viewModel.apply(makeWorkspaceSnapshot(
            currentTab: "chi-square",
            chiSquareA: "12",
            chiSquareB: "18",
            chiSquareC: "7",
            chiSquareD: "9",
            chiSquareUseYates: true
        ))
        XCTAssertEqual(viewModel.a, "12")
        XCTAssertEqual(viewModel.d, "9")
        XCTAssertTrue(viewModel.useYates)
        viewModel.handle(.reset)
        XCTAssertNil(viewModel.scene)
        XCTAssertEqual(viewModel.a, "")
    }

    func testKWICPageViewModelAppliesSnapshotAndRebuildsScene() {
        let viewModel = KWICPageViewModel()
        let snapshot = makeWorkspaceSnapshot(searchQuery: "  alpha  ")
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.keyword, "  alpha  ")
        XCTAssertEqual(viewModel.normalizedKeyword, "alpha")
        XCTAssertEqual(viewModel.leftWindowValue, 3)
        XCTAssertEqual(viewModel.rightWindowValue, 4)

        viewModel.apply(makeKWICResult(rowCount: 40))
        viewModel.handle(.changeSort(.sentenceAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.sentenceIndexText, "2")
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.sentenceIndex) ?? true)

        viewModel.handle(.toggleColumn(.leftContext))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.leftContext) ?? true)
        XCTAssertNotNil(viewModel.primaryLocatorSource)
    }

    func testKWICPageViewModelSelectionChangesPrimaryLocatorSource() {
        let viewModel = KWICPageViewModel()
        viewModel.keyword = "node"
        viewModel.apply(makeKWICResult(rowCount: 3))

        XCTAssertEqual(viewModel.selectedRowID, "3-0")
        XCTAssertEqual(viewModel.primaryLocatorSource?.sentenceId, 3)

        viewModel.handle(.selectRow("1-2"))

        XCTAssertEqual(viewModel.selectedRowID, "1-2")
        XCTAssertEqual(viewModel.primaryLocatorSource?.sentenceId, 1)
        XCTAssertEqual(viewModel.primaryLocatorSource?.nodeIndex, 2)
    }

    func testKWICPageViewModelFallsBackFromAllPageSizeForLargeResults() {
        let viewModel = KWICPageViewModel()
        let expectation = expectation(description: "kwic fallback scene updated")
        viewModel.keyword = "alpha"
        viewModel.apply(makeKWICResult(rowCount: 1_200))

        viewModel.handle(.changePageSize(.all))

        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testNgramPageViewModelAppliesSnapshotFiltersAndPaging() {
        let viewModel = NgramPageViewModel()
        let snapshot = makeWorkspaceSnapshot(currentTab: "ngram")
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.ngramSizeValue, 2)

        viewModel.apply(makeNgramResult(rowCount: 40, n: 4))
        XCTAssertEqual(viewModel.ngramSizeValue, 4)
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.rank) ?? true)

        viewModel.query = "phrase-1"
        XCTAssertTrue(viewModel.scene?.filteredRows ?? 0 > 0)

        viewModel.handle(.changePageSize(.all))
        XCTAssertEqual(viewModel.pageSizeSnapshotValue, "全部")

        viewModel.handle(.toggleColumn(.count))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.count) ?? true)
    }

    func testCollocatePageViewModelAppliesSnapshotPagingAndColumnVisibility() {
        let viewModel = CollocatePageViewModel()
        let snapshot = makeWorkspaceSnapshot()
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.leftWindowValue, 5)
        XCTAssertEqual(viewModel.rightWindowValue, 6)
        XCTAssertEqual(viewModel.minFreqValue, 2)

        viewModel.apply(makeCollocateResult(rowCount: 40))
        viewModel.handle(.changePageSize(.twentyFive))
        XCTAssertEqual(viewModel.scene?.rows.count, 25)
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.rank) ?? true)

        viewModel.handle(.nextPage)
        XCTAssertEqual(viewModel.scene?.rows.count, 15)

        viewModel.handle(.toggleColumn(.rate))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.rate) ?? true)

        viewModel.recordPendingRunConfiguration()
        viewModel.keyword = "updated"
        XCTAssertTrue(viewModel.hasPendingRunChanges)

        viewModel.handle(.changeFocusMetric(.mutualInformation))
        XCTAssertEqual(viewModel.scene?.focusMetric, .mutualInformation)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.mutualInformation) ?? false)
        XCTAssertEqual(viewModel.selectedSceneRow?.id, viewModel.selectedRowID)
    }

    func testCollocatePageViewModelApplyPresetTriggersSingleInputCallbackAndUpdatesScene() {
        let viewModel = CollocatePageViewModel()
        viewModel.apply(makeCollocateResult(rowCount: 40))
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.handle(.applyPreset(.strictAssociation))

        XCTAssertEqual(inputChangeCount, 1)
        XCTAssertEqual(viewModel.leftWindow, "4")
        XCTAssertEqual(viewModel.rightWindow, "4")
        XCTAssertEqual(viewModel.minFreq, "3")
        XCTAssertEqual(viewModel.focusMetric, .mutualInformation)
        XCTAssertEqual(viewModel.scene?.focusMetric, .mutualInformation)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.mutualInformation) ?? false)
    }

    func testLocatorPageViewModelTracksSourcePagingAndColumns() {
        let viewModel = LocatorPageViewModel()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        viewModel.updateSource(source)
        viewModel.apply(makeLocatorResult(rowCount: 30), source: source)

        XCTAssertEqual(viewModel.scene?.rows.count, 30)

        viewModel.handle(.changePageSize(.twentyFive))
        XCTAssertEqual(viewModel.scene?.rows.count, 25)

        viewModel.handle(.toggleColumn(.status))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.status) ?? true)
    }

    func testLocatorPageViewModelActivationPromotesSelectedRowSource() {
        let viewModel = LocatorPageViewModel()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        viewModel.updateSource(source)
        viewModel.apply(makeLocatorResult(rowCount: 4), source: source)

        viewModel.handle(.selectRow("3"))
        viewModel.handle(.activateRow("3"))

        XCTAssertEqual(viewModel.selectedRowID, "3")
        XCTAssertEqual(viewModel.currentSource?.sentenceId, 3)
        XCTAssertEqual(viewModel.currentSource?.nodeIndex, 2)
    }

    func testLocatorPageViewModelBuildsLargeScenesOffMainPath() {
        let viewModel = LocatorPageViewModel()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        let expectation = expectation(description: "large locator scene built")

        viewModel.updateSource(source)
        viewModel.apply(
            makeLocatorResult(rowCount: LargeResultSceneBuildSupport.asyncThreshold + 50),
            source: source
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(viewModel.scene?.totalRows, LargeResultSceneBuildSupport.asyncThreshold + 50)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }

    func testLibraryManagementViewModelBuildsInspectorAndFiltersCorpora() {
        let viewModel = LibraryManagementViewModel()
        let snapshot = makeBootstrapState().librarySnapshot
        viewModel.applyBootstrap(snapshot)

        XCTAssertEqual(viewModel.scene.corpora.count, 2)
        XCTAssertEqual(viewModel.scene.navigationSelection, .allCorpora)
        XCTAssertNil(viewModel.scene.inspector)

        viewModel.selectFolder("folder-1")
        XCTAssertEqual(viewModel.scene.corpora.count, 2)
        XCTAssertEqual(viewModel.scene.navigationSelection, .folder("folder-1"))
        XCTAssertEqual(viewModel.scene.inspector?.title, "Default")

        viewModel.selectCorpus("corpus-2")
        XCTAssertEqual(viewModel.scene.selectedCorpusID, "corpus-2")
        XCTAssertEqual(viewModel.scene.inspector?.title, "Compare Corpus")
        XCTAssertEqual(viewModel.scene.inspector?.actions.first?.action, .openSelectedCorpus)
        XCTAssertTrue(viewModel.scene.inspector?.actions.contains(where: { $0.action == .showSelectedCorpusInfo }) ?? false)
        XCTAssertTrue(viewModel.scene.inspector?.actions.contains(where: { $0.action == .editSelectedCorpusMetadata }) ?? false)
        XCTAssertTrue(viewModel.scene.inspector?.details.contains(where: { $0.title == "体裁" && $0.value == "学术" }) ?? false)
    }

    func testLibraryManagementViewModelSupportsBatchSelectionAndIntegritySummary() {
        let viewModel = LibraryManagementViewModel()
        let snapshot = LibrarySnapshot(
            folders: [LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])],
            corpora: [
                LibraryCorpusItem(json: [
                    "id": "corpus-1",
                    "name": "Corpus A",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "representedPath": "/tmp/a.txt",
                    "metadata": [
                        "sourceLabel": "教材",
                        "yearLabel": "",
                        "genreLabel": "教学",
                        "tags": []
                    ]
                ]),
                LibraryCorpusItem(json: [
                    "id": "corpus-2",
                    "name": "Corpus B",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "representedPath": "/tmp/b.txt",
                    "metadata": [
                        "sourceLabel": "期刊",
                        "yearLabel": "2023",
                        "genreLabel": "",
                        "tags": ["研究"]
                    ]
                ])
            ]
        )

        viewModel.applyBootstrap(snapshot)
        viewModel.selectCorpusIDs(["corpus-1", "corpus-2"])

        XCTAssertEqual(viewModel.scene.selectedCorpusIDs, Set(["corpus-1", "corpus-2"]))
        XCTAssertEqual(viewModel.scene.inspector?.title, "已选择 2 条语料")
        XCTAssertEqual(viewModel.scene.integritySummary.missingYearCount, 1)
        XCTAssertEqual(viewModel.scene.integritySummary.missingGenreCount, 1)
        XCTAssertEqual(viewModel.scene.integritySummary.missingTagsCount, 1)
    }

    func testLibraryManagementViewModelSelectingCorpusSetAppliesSavedMembersAndMetadataFilter() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教学语料集",
            "corpusIds": ["corpus-1"],
            "corpusNames": ["Demo Corpus"],
            "metadataFilter": [
                "sourceQuery": "教材",
                "yearQuery": "2024",
                "genreQuery": "",
                "tagsQuery": ""
            ],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = LibraryManagementViewModel()
        viewModel.applyBootstrap(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)
        viewModel.selectFolder("folder-1")

        viewModel.selectCorpusSet("set-1")

        XCTAssertEqual(viewModel.selectedCorpusSetID, "set-1")
        XCTAssertNil(viewModel.selectedFolderID)
        XCTAssertEqual(viewModel.metadataFilterState, savedSet.metadataFilterState)
        XCTAssertEqual(viewModel.metadataFilterState.yearFrom, "2024")
        XCTAssertEqual(viewModel.metadataFilterState.yearTo, "2024")
        XCTAssertEqual(viewModel.selectedCorpusIDs, Set(["corpus-1"]))
        XCTAssertEqual(viewModel.selectedCorpusID, "corpus-1")
        XCTAssertEqual(viewModel.saveableCorpusSetMembers.map(\.id), ["corpus-1"])
        XCTAssertEqual(viewModel.scene.selectedCorpusSetID, "set-1")
        XCTAssertEqual(viewModel.scene.navigationSelection, .savedCorpusSet("set-1"))
    }

    func testLibraryManagementViewModelBuildsRecentCorpusSetSceneItems() {
        let savedSetOne = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教学语料集",
            "corpusIds": ["corpus-1"],
            "corpusNames": ["Demo Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let savedSetTwo = LibraryCorpusSetItem(json: [
            "id": "set-2",
            "name": "对比语料集",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = LibraryManagementViewModel()
        viewModel.applyBootstrap(makeBootstrapState(corpusSets: [savedSetOne, savedSetTwo]).librarySnapshot)

        viewModel.applyRecentCorpusSetIDs(["set-2"])

        XCTAssertEqual(viewModel.scene.recentCorpusSets.map(\.id), ["set-2"])
        XCTAssertEqual(viewModel.scene.corpusSets.map(\.id), ["set-1"])
        XCTAssertEqual(viewModel.scene.recentCorpusSetsSummary, "最近使用 1 项")
    }

    func testLibraryManagementViewModelSelectingRecycleBinSwitchesPrimaryContent() {
        let viewModel = LibraryManagementViewModel()
        viewModel.applyBootstrap(makeBootstrapState().librarySnapshot)
        viewModel.applyRecycleSnapshot(
            RecycleBinSnapshot(
                entries: [
                    RecycleBinEntry(json: [
                        "recycleEntryId": "recycle-1",
                        "name": "Deleted Corpus",
                        "type": "corpus",
                        "deletedAt": "today",
                        "originalFolderName": "Default",
                        "sourceType": "txt",
                        "itemCount": 1
                    ])
                ],
                folderCount: 0,
                corpusCount: 1,
                totalCount: 1
            )
        )

        viewModel.selectRecycleEntry(nil)

        XCTAssertEqual(viewModel.scene.navigationSelection, .recycleBin)
        XCTAssertEqual(viewModel.scene.content.mode, .recycleBin)
        XCTAssertEqual(viewModel.scene.selectedRecycleEntryID, nil)
    }

    func testLibraryManagementViewModelSearchQueryFiltersVisibleContentAndAddsSearchChip() {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Compare Collection",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let viewModel = LibraryManagementViewModel()
        viewModel.applyBootstrap(makeBootstrapState(corpusSets: [savedSet]).librarySnapshot)
        viewModel.applyRecentCorpusSetIDs(["set-1"])

        viewModel.searchQuery = "Compare"

        XCTAssertEqual(viewModel.scene.corpora.map(\.id), ["corpus-2"])
        XCTAssertEqual(viewModel.scene.recentCorpusSets.map(\.id), ["set-1"])
        XCTAssertTrue(viewModel.scene.filterChips.contains(where: { $0.id == "search-query" && $0.title.contains("Compare") }))
        XCTAssertTrue(viewModel.scene.librarySummary.contains("Compare"))
    }

    func testLibraryManagementViewModelBuildsCleaningSummaryAndImportSummaryScene() {
        let viewModel = LibraryManagementViewModel()
        let snapshot = LibrarySnapshot(
            folders: [LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])],
            corpora: [
                LibraryCorpusItem(json: [
                    "id": "corpus-cleaned",
                    "name": "Corpus Cleaned",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "cleaningStatus": "cleaned",
                    "cleaningSummary": makeCleaningReportSummary(
                        status: .cleaned,
                        ruleHits: []
                    ).jsonObject
                ]),
                LibraryCorpusItem(json: [
                    "id": "corpus-changed",
                    "name": "Corpus Changed",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "cleaningStatus": "cleanedWithChanges",
                    "cleaningSummary": makeCleaningReportSummary().jsonObject
                ]),
                LibraryCorpusItem(json: [
                    "id": "corpus-pending",
                    "name": "Corpus Pending",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "cleaningStatus": "pending"
                ])
            ]
        )

        viewModel.applyBootstrap(snapshot)

        XCTAssertEqual(viewModel.scene.autoCleaningSummary.cleanedCount, 1)
        XCTAssertEqual(viewModel.scene.autoCleaningSummary.pendingCount, 1)
        XCTAssertEqual(viewModel.scene.autoCleaningSummary.changedCount, 1)

        let summaryScene = viewModel.makeImportSummaryScene(
            result: LibraryImportResult(json: [
                "importedCount": 2,
                "skippedCount": 1,
                "importedItems": [],
                "failureItems": [[
                    "fileName": "bad.pdf",
                    "reason": "无法读取"
                ]],
                "cleaningSummary": [
                    "cleanedCount": 2,
                    "changedCount": 1,
                    "ruleHits": [
                        ["id": "space-normalization", "count": 3]
                    ]
                ],
                "cancelled": false
            ])
        )

        XCTAssertEqual(summaryScene.cleanedCountText, "2")
        XCTAssertEqual(summaryScene.changedCountText, "1")
        XCTAssertTrue(summaryScene.ruleHitsSummaryText.contains("3"))
        XCTAssertTrue(summaryScene.firstFailureText.contains("bad.pdf"))
    }

    func testTopicsPageViewModelAppliesSnapshotWithoutTriggeringRepeatedInputCallbacks() {
        let viewModel = TopicsPageViewModel()
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.apply(makeTopicAnalysisResult())
        viewModel.apply(makeWorkspaceSnapshot(searchQuery: "hack*", topicsKeywordDisplayCount: "8"))

        XCTAssertEqual(inputChangeCount, 0)
        XCTAssertEqual(viewModel.query, "hack*")
        XCTAssertEqual(viewModel.keywordDisplayCount, "8")
        XCTAssertEqual(viewModel.scene?.query, "hack*")
        XCTAssertEqual(viewModel.scene?.controls.keywordDisplayCount, 8)
        XCTAssertEqual(viewModel.scene?.visibleSegments, 2)
    }

    func testTopicsPageViewModelClampsKeywordDisplayCountAndKeepsBuiltResult() {
        let viewModel = TopicsPageViewModel()
        viewModel.apply(makeTopicAnalysisResult())

        XCTAssertEqual(viewModel.scene?.controls.keywordDisplayCount, 5)

        viewModel.keywordDisplayCount = "20"

        XCTAssertEqual(viewModel.keywordDisplayCountValue, 12)
        XCTAssertEqual(viewModel.scene?.controls.keywordDisplayCount, 12)
        XCTAssertNotNil(viewModel.result)
        XCTAssertEqual(viewModel.scene?.visibleSegments, 2)

        viewModel.keywordDisplayCount = "0"

        XCTAssertEqual(viewModel.keywordDisplayCountValue, 1)
        XCTAssertEqual(viewModel.scene?.controls.keywordDisplayCount, 1)
        XCTAssertNotNil(viewModel.result)
    }

    func testTokenizePageViewModelBuildsFilteredExportDocument() {
        let viewModel = TokenizePageViewModel()
        let snapshot = makeWorkspaceSnapshot(
            currentTab: "tokenize",
            searchQuery: "alpha",
            tokenizeLanguagePreset: .latinFocused,
            tokenizeLemmaStrategy: .lemmaPreferred
        )
        viewModel.apply(snapshot)
        viewModel.apply(makeTokenizeResult())

        XCTAssertEqual(viewModel.languagePreset, .latinFocused)
        XCTAssertEqual(viewModel.lemmaStrategy, .lemmaPreferred)
        XCTAssertEqual(viewModel.scene?.filteredTokens, 2)
        XCTAssertEqual(viewModel.scene?.visibleSentences, 2)
        XCTAssertEqual(viewModel.exportDocument?.text, "alpha\nalpha\n")
        XCTAssertEqual(viewModel.scene?.sorting.selectedLanguagePreset, .latinFocused)
        XCTAssertEqual(viewModel.scene?.sorting.selectedLemmaStrategy, .lemmaPreferred)
        XCTAssertEqual(viewModel.scene?.rows.first?.lemma, "alpha")
        XCTAssertTrue(
            [TokenScript.latin.title(in: .system), TokenScript.latin.title(in: .english), TokenScript.latin.title(in: .chinese)]
                .contains(viewModel.scene?.rows.first?.script ?? "")
        )
        XCTAssertFalse(viewModel.scene?.column(for: .position)?.isVisible ?? true)
        XCTAssertTrue(viewModel.scene?.column(for: .lemma)?.isVisible ?? false)

        viewModel.handle(.toggleColumn(.normalized))
        XCTAssertFalse(viewModel.scene?.column(for: .normalized)?.isVisible ?? true)
    }

    func testWordPageViewModelAppliesSnapshotWithoutTriggeringRepeatedInputCallbacks() {
        let viewModel = WordPageViewModel()
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.apply(makeStatsResult(rowCount: 12))
        viewModel.apply(makeWorkspaceSnapshot(searchQuery: "Alpha", frequencyNormalizationUnit: .perMillion, frequencyRangeMode: .paragraph))

        XCTAssertEqual(inputChangeCount, 0)
        XCTAssertEqual(viewModel.query, "Alpha")
        XCTAssertEqual(viewModel.metricDefinition.normalizationUnit, .perMillion)
        XCTAssertEqual(viewModel.metricDefinition.rangeMode, .paragraph)
        XCTAssertEqual(viewModel.scene?.query, "Alpha")
    }

    func testNgramPageViewModelSnapshotAndResultDoNotTriggerInputCallbacks() {
        let viewModel = NgramPageViewModel()
        var inputChangeCount = 0
        viewModel.onInputChange = {
            inputChangeCount += 1
        }

        viewModel.apply(makeWorkspaceSnapshot(searchQuery: "beta", ngramSize: "4"))
        viewModel.apply(makeNgramResult(rowCount: 10, n: 4))

        XCTAssertEqual(inputChangeCount, 0)
        XCTAssertEqual(viewModel.query, "beta")
        XCTAssertEqual(viewModel.ngramSizeValue, 4)
        XCTAssertEqual(viewModel.scene?.query, "beta")
    }

    func testWordPageViewModelBuildsLargeScenesOffMainPath() {
        let viewModel = WordPageViewModel()
        let expectation = expectation(description: "large scene built")

        viewModel.apply(makeStatsResult(rowCount: LargeResultSceneBuildSupport.asyncThreshold + 50))

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            XCTAssertEqual(viewModel.scene?.totalRows, LargeResultSceneBuildSupport.asyncThreshold + 50)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1.0)
    }
}
