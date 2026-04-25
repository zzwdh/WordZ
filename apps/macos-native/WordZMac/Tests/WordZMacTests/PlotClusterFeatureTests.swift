import XCTest
@testable import WordZWorkspaceCore

final class PlotClusterAnalysisEngineTests: XCTestCase {
    func testRunPlotBuildsNormalizedHitMarkersForWholeWordQuery() throws {
        let engine = NativeAnalysisEngine()

        let result = try engine.runPlot(
            text: "alpha alphabeta alpha gamma alpha",
            keyword: "alpha",
            searchOptions: .default
        )

        XCTAssertEqual(result.tokenCount, 5)
        XCTAssertEqual(result.hitMarkers.map(\.id), ["0-0", "0-2", "0-4"])
        XCTAssertEqual(result.hitMarkers.map(\.normalizedPosition), [0, 0.5, 1])
        XCTAssertTrue(result.hitMarkers.allSatisfy { (0...1).contains($0.normalizedPosition) })
    }

    func testRunPlotArtifactRegexFallbackStillProducesMarkers() throws {
        let engine = NativeAnalysisEngine()
        let text = "alpha beta alphabet"
        let documentKey = DocumentCacheKey(text: text)
        let artifact = StoredTokenizedArtifact(
            textDigest: documentKey.textDigest,
            document: engine.indexedDocument(for: text, documentKey: documentKey).document
        )

        let result = try engine.runPlot(
            artifact: artifact,
            keyword: "alpha.*",
            searchOptions: SearchOptionsState(words: false, regex: true)
        )

        XCTAssertEqual(result.tokenCount, 3)
        XCTAssertEqual(result.hitMarkers.map(\.id), ["0-0", "0-2"])
        XCTAssertTrue(result.hitMarkers.allSatisfy { (0...1).contains($0.normalizedPosition) })
    }

    func testRunPlotArtifactPhraseExactSupportsCandidateSentenceFastPath() throws {
        let engine = NativeAnalysisEngine()
        let text = "Alpha beta gamma.\nAlpha delta theta.\nAlpha beta again."
        let documentKey = DocumentCacheKey(text: text)
        let artifact = StoredTokenizedArtifact(
            textDigest: documentKey.textDigest,
            document: engine.indexedDocument(for: text, documentKey: documentKey).document
        )

        let result = try engine.runPlot(
            artifact: artifact,
            candidateSentenceIDs: Set([0, 2]),
            keyword: "alpha beta",
            searchOptions: SearchOptionsState(matchMode: .phraseExact)
        )

        XCTAssertEqual(result.tokenCount, 9)
        XCTAssertEqual(result.hitMarkers.map(\.id), ["0-0", "2-0"])
        XCTAssertEqual(result.hitMarkers.map(\.sentenceId), [0, 2])
        XCTAssertEqual(result.hitMarkers.map(\.normalizedPosition), [0, 0.75])
    }

    func testRunKWICPhraseExactMatchesContiguousTokensWithinSentence() throws {
        let engine = NativeAnalysisEngine()

        let result = try engine.runKWIC(
            text: "Alpha beta gamma. Alpha beta. Alpha gamma beta.",
            keyword: "alpha beta",
            leftWindow: 1,
            rightWindow: 1,
            searchOptions: SearchOptionsState(matchMode: .phraseExact)
        )

        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows.map(\.node), ["Alpha beta", "Alpha beta"])
        XCTAssertEqual(result.rows.first?.right, "gamma")
        XCTAssertEqual(result.rows.last?.right, "")
    }

    func testRunClusterGeneratesRequestedNgramsWithoutCrossingSentenceBoundaries() {
        let engine = NativeAnalysisEngine()
        let request = ClusterRunRequest(
            targetEntries: [
                ClusterCorpusEntry(
                    corpusId: "doc-1",
                    corpusName: "Doc 1",
                    content: "alpha beta gamma delta epsilon. alpha beta gamma delta epsilon."
                )
            ],
            referenceEntries: [],
            caseSensitive: false,
            stopwordFilter: .default,
            punctuationMode: .boundary,
            nValues: [2, 3, 4, 5]
        )

        let result = engine.runCluster(request)

        XCTAssertEqual(result.rows.first(where: { $0.phrase == "alpha beta" && $0.n == 2 })?.frequency, 2)
        XCTAssertEqual(result.rows.first(where: { $0.phrase == "alpha beta gamma" && $0.n == 3 })?.frequency, 2)
        XCTAssertEqual(result.rows.first(where: { $0.phrase == "alpha beta gamma delta" && $0.n == 4 })?.frequency, 2)
        XCTAssertEqual(result.rows.first(where: { $0.phrase == "alpha beta gamma delta epsilon" && $0.n == 5 })?.frequency, 2)
        XCTAssertNil(result.rows.first(where: { $0.phrase == "epsilon alpha" }))
    }

    func testRunClusterPunctuationBoundaryAndStripBridgeDiffer() {
        let engine = NativeAnalysisEngine()
        let boundaryRequest = ClusterRunRequest(
            targetEntries: [
                ClusterCorpusEntry(corpusId: "doc-1", corpusName: "Doc 1", content: "alpha, beta gamma")
            ],
            referenceEntries: [],
            caseSensitive: false,
            stopwordFilter: .default,
            punctuationMode: .boundary,
            nValues: [2]
        )
        let bridgeRequest = ClusterRunRequest(
            targetEntries: boundaryRequest.targetEntries,
            referenceEntries: [],
            caseSensitive: false,
            stopwordFilter: .default,
            punctuationMode: .stripAndBridge,
            nValues: [2]
        )

        let boundary = engine.runCluster(boundaryRequest)
        let bridge = engine.runCluster(bridgeRequest)

        XCTAssertNil(boundary.rows.first(where: { $0.phrase == "alpha beta" }))
        XCTAssertEqual(bridge.rows.first(where: { $0.phrase == "alpha beta" })?.frequency, 1)
    }

    func testRunClusterPreservesInternalApostrophesAndCandidateLevelStopwordFiltering() {
        let engine = NativeAnalysisEngine()
        let baseEntries = [
            ClusterCorpusEntry(
                corpusId: "doc-1",
                corpusName: "Doc 1",
                content: "don't know don't know of course of course alpha beta"
            )
        ]

        let excluded = engine.runCluster(
            ClusterRunRequest(
                targetEntries: baseEntries,
                referenceEntries: [],
                caseSensitive: false,
                stopwordFilter: StopwordFilterState(enabled: true, mode: .exclude, listText: "of"),
                punctuationMode: .boundary,
                nValues: [2]
            )
        )
        let included = engine.runCluster(
            ClusterRunRequest(
                targetEntries: baseEntries,
                referenceEntries: [],
                caseSensitive: false,
                stopwordFilter: StopwordFilterState(enabled: true, mode: .include, listText: "of\ncourse"),
                punctuationMode: .boundary,
                nValues: [2]
            )
        )

        XCTAssertEqual(excluded.rows.first(where: { $0.phrase == "don't know" })?.frequency, 2)
        XCTAssertNil(excluded.rows.first(where: { $0.phrase == "of course" }))
        XCTAssertTrue(included.rows.map(\.phrase).contains("of course"))
        XCTAssertFalse(included.rows.map(\.phrase).contains("alpha beta"))
        XCTAssertEqual(included.rows.first(where: { $0.phrase == "of course" })?.frequency, 2)
    }

    func testRunClusterComputesRangeAndReferenceMetrics() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runCluster(
            ClusterRunRequest(
                targetEntries: [
                    ClusterCorpusEntry(corpusId: "doc-1", corpusName: "Doc 1", content: "Alpha beta alpha beta"),
                    ClusterCorpusEntry(corpusId: "doc-2", corpusName: "Doc 2", content: "alpha beta gamma")
                ],
                referenceEntries: [
                    ClusterCorpusEntry(corpusId: "ref-1", corpusName: "Ref 1", content: "gamma gamma gamma")
                ],
                caseSensitive: false,
                stopwordFilter: .default,
                punctuationMode: .boundary,
                nValues: [2]
            )
        )

        let row = try XCTUnwrap(result.rows.first(where: { $0.phrase == "alpha beta" }))
        XCTAssertEqual(row.frequency, 3)
        XCTAssertEqual(row.range, 2)
        XCTAssertEqual(row.referenceFrequency, 0)
        XCTAssertEqual(row.referenceRange, 0)
        XCTAssertGreaterThan(row.logRatio ?? 0, 0)
    }
}

@MainActor
final class PlotClusterSceneAndViewModelTests: XCTestCase {
    func testPlotSceneBuilderBuildsBackingTableRowsAndMetadata() {
        let result = makePlotResult(
            query: "alpha",
            scope: .corpusRange,
            rows: [
                PlotRow(
                    id: "corpus-2",
                    corpusId: "corpus-2",
                    fileID: 1,
                    filePath: "/tmp/compare.txt",
                    displayName: "Compare Corpus",
                    fileTokens: 80,
                    frequency: 2,
                    normalizedFrequency: 250,
                    hitMarkers: [
                        PlotHitMarker(id: "0-1", sentenceId: 0, tokenIndex: 1, normalizedPosition: 0.25),
                        PlotHitMarker(id: "1-3", sentenceId: 1, tokenIndex: 3, normalizedPosition: 0.75)
                    ]
                ),
                PlotRow(
                    id: "corpus-1",
                    corpusId: "corpus-1",
                    fileID: 0,
                    filePath: "/tmp/demo.txt",
                    displayName: "Demo Corpus",
                    fileTokens: 120,
                    frequency: 5,
                    normalizedFrequency: 416.6667,
                    hitMarkers: [
                        PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0)
                    ]
                )
            ]
        )
        let builder = PlotSceneBuilder()
        let sortedRows = builder.sortedRows(from: result)

        let scene = builder.build(
            from: result,
            sortedRows: sortedRows,
            selectedRowID: "corpus-2",
            selectedMarkerID: "0-1",
            languageMode: .english
        )

        XCTAssertEqual(scene.rows.map(\.id), ["corpus-1", "corpus-2"])
        XCTAssertEqual(scene.selectedRowID, "corpus-2")
        XCTAssertEqual(scene.selectedMarkerID, "0-1")
        XCTAssertEqual(scene.table.storageKey, "plot")
        XCTAssertEqual(scene.tableRows.first?.value(for: PlotColumnKey.row.rawValue), "1")
        XCTAssertEqual(scene.tableRows.first?.value(for: PlotColumnKey.fileID.rawValue), "0")
        XCTAssertEqual(scene.tableRows.first?.value(for: PlotColumnKey.filePath.rawValue), "/tmp/demo.txt")
        XCTAssertEqual(scene.tableRows.first?.value(for: PlotColumnKey.frequency.rawValue), "5")
        XCTAssertEqual(scene.tableRows.last?.value(for: PlotColumnKey.plot.rawValue), "0.25 | 0.75")
        XCTAssertTrue(scene.exportMetadataLines.contains("Query: alpha"))
        XCTAssertTrue(scene.exportMetadataLines.contains("Scope: Current Corpus Range"))
        XCTAssertTrue(scene.exportMetadataLines.contains("Total Hits: 7"))
    }

    func testPlotPageViewModelRestoresSnapshotAndKeepsMarkerSelectionInSync() {
        let viewModel = PlotPageViewModel()
        viewModel.apply(
            WorkspaceSnapshotSummary(json: [
                "plot": [
                    "query": "alpha",
                    "options": [
                        "words": true,
                        "caseSensitive": true,
                        "regex": false,
                        "matchMode": SearchMatchMode.token.rawValue
                    ]
                ]
            ])
        )

        XCTAssertEqual(viewModel.query, "alpha")
        XCTAssertEqual(viewModel.searchOptions.caseSensitive, true)

        viewModel.apply(
            makePlotResult(
                query: "alpha",
                rows: [
                    PlotRow(
                        id: "corpus-1",
                        corpusId: "corpus-1",
                        fileID: 0,
                        filePath: "/tmp/demo.txt",
                        displayName: "Demo Corpus",
                        fileTokens: 100,
                        frequency: 4,
                        normalizedFrequency: 400,
                        hitMarkers: [
                            PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0),
                            PlotHitMarker(id: "0-2", sentenceId: 0, tokenIndex: 2, normalizedPosition: 0.5)
                        ]
                    ),
                    PlotRow(
                        id: "corpus-2",
                        corpusId: "corpus-2",
                        fileID: 1,
                        filePath: "/tmp/compare.txt",
                        displayName: "Compare Corpus",
                        fileTokens: 80,
                        frequency: 1,
                        normalizedFrequency: 125,
                        hitMarkers: [
                            PlotHitMarker(id: "1-1", sentenceId: 1, tokenIndex: 1, normalizedPosition: 0.25)
                        ]
                    )
                ]
            )
        )

        XCTAssertEqual(viewModel.selectedSceneRow?.id, "corpus-1")
        XCTAssertNil(viewModel.selectedMarkerID)

        viewModel.handle(.selectMarker(rowID: "corpus-1", markerID: "0-2"))
        XCTAssertEqual(viewModel.selectedSceneMarker?.id, "0-2")

        viewModel.handle(.selectRow("corpus-2"))
        XCTAssertEqual(viewModel.selectedSceneRow?.id, "corpus-2")
        XCTAssertNil(viewModel.selectedMarkerID)
    }

    func testClusterSceneBuilderFiltersPhraseExactAndSortsAlphabetically() {
        let result = ClusterResult(
            mode: .targetReference,
            targetDocumentCount: 2,
            referenceDocumentCount: 1,
            targetTokenCount: 100,
            referenceTokenCount: 80,
            rows: [
                ClusterRow(
                    phrase: "beta gamma",
                    n: 2,
                    frequency: 6,
                    normalizedFrequency: 600,
                    range: 2,
                    rangePercentage: 100,
                    referenceFrequency: 1,
                    referenceNormalizedFrequency: 50,
                    referenceRange: 1,
                    logRatio: 1.0
                ),
                ClusterRow(
                    phrase: "alpha beta",
                    n: 2,
                    frequency: 6,
                    normalizedFrequency: 600,
                    range: 2,
                    rangePercentage: 100,
                    referenceFrequency: 0,
                    referenceNormalizedFrequency: 0,
                    referenceRange: 0,
                    logRatio: 2.0
                ),
                ClusterRow(
                    phrase: "alpha beta gamma",
                    n: 3,
                    frequency: 3,
                    normalizedFrequency: 300,
                    range: 1,
                    rangePercentage: 50,
                    referenceFrequency: 0,
                    referenceNormalizedFrequency: 0,
                    referenceRange: 0,
                    logRatio: 1.2
                )
            ]
        )

        let scene = ClusterSceneBuilder().build(
            from: result,
            query: "alpha beta",
            searchOptions: SearchOptionsState(matchMode: .phraseExact),
            stopwordFilter: .default,
            selectedN: 2,
            minimumFrequency: 1,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(ClusterColumnKey.allCases),
            selectedRowID: nil,
            caseSensitive: false,
            punctuationMode: .boundary,
            languageMode: .english
        )

        XCTAssertEqual(scene.rows.map(\.phrase), ["alpha beta"])
        XCTAssertEqual(scene.filteredRows, 1)
        XCTAssertEqual(scene.table.storageKey, "cluster")
        XCTAssertEqual(scene.tableRows.first?.value(for: ClusterColumnKey.frequency.rawValue), "6")
    }
}

final class PlotClusterPersistenceTests: XCTestCase {
    func testWorkspaceSnapshotDefaultsPlotAndClusterFieldsWhenMissing() {
        let snapshot = WorkspaceSnapshotSummary(json: [:])

        XCTAssertEqual(snapshot.plotQuery, "")
        XCTAssertEqual(snapshot.plotSearchOptions, .default)
        XCTAssertEqual(snapshot.clusterSelectedN, "3")
        XCTAssertEqual(snapshot.clusterMinFrequency, "3")
        XCTAssertEqual(snapshot.clusterSortMode, .frequencyDescending)
        XCTAssertEqual(snapshot.clusterPunctuationMode, .boundary)
        XCTAssertEqual(snapshot.clusterPageSize, "100")
        XCTAssertEqual(snapshot.clusterReferenceCorpusID, "")
    }

    func testNativePersistedWorkspaceSnapshotRoundTripsPlotAndClusterFields() {
        let draft = WorkspaceStateDraft(
            currentTab: WorkspaceDetailTab.cluster.snapshotValue,
            currentLibraryFolderId: "folder-1",
            selectedCorpusSetID: "",
            corpusIds: ["corpus-1"],
            corpusNames: ["Demo Corpus"],
            searchQuery: "alpha beta",
            searchOptions: SearchOptionsState(matchMode: .phraseExact),
            stopwordFilter: .default,
            tokenizeLanguagePreset: .mixedChineseEnglish,
            tokenizeLemmaStrategy: .normalizedSurface,
            compareReferenceCorpusID: "",
            compareSelectedCorpusIDs: [],
            keywordActiveTab: .words,
            keywordSuiteConfiguration: .default,
            keywordTargetCorpusID: "",
            keywordReferenceCorpusID: "",
            keywordLowercased: true,
            keywordRemovePunctuation: true,
            keywordMinimumFrequency: "2",
            keywordStatistic: .logLikelihood,
            keywordStopwordFilter: .default,
            plotQuery: "alpha",
            plotSearchOptions: SearchOptionsState(words: true, caseSensitive: true, regex: false, matchMode: .token),
            ngramSize: "2",
            ngramPageSize: "10",
            clusterSelectedN: "4",
            clusterMinFrequency: "5",
            clusterSortMode: .alphabeticalAscending,
            clusterCaseSensitive: true,
            clusterStopwordFilter: StopwordFilterState(enabled: true, mode: .exclude, listText: "the"),
            clusterPunctuationMode: .stripAndBridge,
            clusterSelectedPhrase: "alpha beta gamma delta",
            clusterPageSize: "250",
            clusterReferenceCorpusID: "corpus-2",
            kwicLeftWindow: "5",
            kwicRightWindow: "5",
            collocateLeftWindow: "5",
            collocateRightWindow: "5",
            collocateMinFreq: "2",
            topicsMinTopicSize: "2",
            topicsIncludeOutliers: true,
            topicsPageSize: "50",
            topicsActiveTopicID: "",
            frequencyNormalizationUnit: .perThousand,
            frequencyRangeMode: .sentence,
            chiSquareA: "",
            chiSquareB: "",
            chiSquareC: "",
            chiSquareD: "",
            chiSquareUseYates: false
        )

        let snapshot = NativePersistedWorkspaceSnapshot(draft: draft).workspaceSnapshot

        XCTAssertEqual(snapshot.currentTab, WorkspaceDetailTab.cluster.snapshotValue)
        XCTAssertEqual(snapshot.searchOptions.matchMode, .phraseExact)
        XCTAssertEqual(snapshot.plotQuery, "alpha")
        XCTAssertEqual(snapshot.plotSearchOptions.caseSensitive, true)
        XCTAssertEqual(snapshot.clusterSelectedN, "4")
        XCTAssertEqual(snapshot.clusterMinFrequency, "5")
        XCTAssertEqual(snapshot.clusterSortMode, .alphabeticalAscending)
        XCTAssertTrue(snapshot.clusterCaseSensitive)
        XCTAssertEqual(snapshot.clusterPunctuationMode, .stripAndBridge)
        XCTAssertEqual(snapshot.clusterSelectedPhrase, "alpha beta gamma delta")
        XCTAssertEqual(snapshot.clusterPageSize, "250")
        XCTAssertEqual(snapshot.clusterReferenceCorpusID, "corpus-2")
    }
}

@MainActor
final class PlotClusterWorkspaceIntegrationTests: XCTestCase {
    func testWorkspaceBootstrapExposesPlotAndClusterTabs() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertTrue(workspace.rootScene.tabs.map(\.tab).contains(.plot))
        XCTAssertTrue(workspace.rootScene.tabs.map(\.tab).contains(.cluster))
    }

    func testRunPlotUsesSingleCorpusScopeWithoutFilters() async throws {
        let repository = FakeWorkspaceRepository(
            plotResult: makePlotResult(
                query: "alpha",
                scope: .singleCorpus,
                searchOptions: SearchOptionsState(words: true, caseSensitive: true, regex: false),
                rows: [
                    PlotRow(
                        id: "corpus-1",
                        corpusId: "corpus-1",
                        fileID: 0,
                        filePath: "/tmp/demo.txt",
                        displayName: "Demo Corpus",
                        fileTokens: 120,
                        frequency: 3,
                        normalizedFrequency: 250,
                        hitMarkers: [
                            PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0),
                            PlotHitMarker(id: "0-4", sentenceId: 0, tokenIndex: 4, normalizedPosition: 0.5),
                            PlotHitMarker(id: "1-2", sentenceId: 1, tokenIndex: 2, normalizedPosition: 1)
                        ]
                    )
                ]
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.plot.query = "alpha"
        workspace.plot.searchOptions = SearchOptionsState(words: true, caseSensitive: true, regex: false)

        await workspace.runPlot()

        let request = try XCTUnwrap(repository.lastRunPlotRequest)
        XCTAssertEqual(repository.runPlotCallCount, 1)
        XCTAssertEqual(request.scope, .singleCorpus)
        XCTAssertEqual(request.entries.count, 1)
        XCTAssertEqual(request.query, "alpha")
        XCTAssertEqual(request.searchOptions.caseSensitive, true)
        XCTAssertEqual(workspace.selectedTab, .plot)
        XCTAssertTrue(workspace.sceneGraph.plot.hasResult)
        XCTAssertEqual(workspace.plot.scene?.rows.count, 1)
        XCTAssertEqual(workspace.currentExportSnapshot?.table.storageKey, "plot")
    }

    func testRunPlotUsesCorpusRangeScopeWhenCorpusSetIsActive() async throws {
        let corpusSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Scope Set",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [corpusSet]),
            plotResult: makePlotResult(query: "alpha", scope: .corpusRange)
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sidebar.applyCorpusSet(repository.bootstrapState.librarySnapshot.corpusSets.first)
        workspace.plot.query = "alpha"

        await workspace.runPlot()

        let request = try XCTUnwrap(repository.lastRunPlotRequest)
        XCTAssertEqual(repository.runPlotCallCount, 1)
        XCTAssertEqual(request.scope, .corpusRange)
        XCTAssertEqual(request.entries.map(\.corpusId), ["corpus-1", "corpus-2"])
        XCTAssertEqual(repository.openSavedCorpusCallCount, 2)
        XCTAssertEqual(workspace.plot.scene?.rows.count, 2)
        XCTAssertEqual(workspace.plot.scene?.scope, .corpusRange)
    }

    func testOpenPlotKWICReusesQueryOptionsAndSelectedMarker() async {
        let repository = FakeWorkspaceRepository(
            plotResult: makePlotResult(
                query: "alpha",
                scope: .singleCorpus,
                searchOptions: SearchOptionsState(words: true, caseSensitive: true, regex: false),
                rows: [
                    PlotRow(
                        id: "corpus-1",
                        corpusId: "corpus-1",
                        fileID: 0,
                        filePath: "/tmp/demo.txt",
                        displayName: "Demo Corpus",
                        fileTokens: 120,
                        frequency: 2,
                        normalizedFrequency: 166.67,
                        hitMarkers: [
                            PlotHitMarker(id: "0-4", sentenceId: 0, tokenIndex: 4, normalizedPosition: 0.5),
                            PlotHitMarker(id: "1-2", sentenceId: 1, tokenIndex: 2, normalizedPosition: 1)
                        ]
                    )
                ]
            ),
            kwicResult: KWICResult(
                rows: [
                    KWICRow(
                        id: "0-4",
                        left: "left",
                        node: "alpha",
                        right: "right",
                        sentenceId: 0,
                        sentenceTokenIndex: 4
                    )
                ]
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.plot.query = "alpha"
        workspace.plot.searchOptions = SearchOptionsState(words: true, caseSensitive: true, regex: false)

        await workspace.runPlot()
        workspace.plot.handle(.selectMarker(rowID: "corpus-1", markerID: "0-4"))

        await workspace.openPlotKWIC()

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(repository.lastRunKWICSearchOptions, SearchOptionsState(words: true, caseSensitive: true, regex: false))
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.kwic.selectedRowID, "0-4")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }

    func testRunClusterAndOpenClusterKWICUsePhraseExactDrilldown() async {
        let repository = FakeWorkspaceRepository()
        repository.clusterResult = ClusterResult(
            mode: .targetOnly,
            targetDocumentCount: 1,
            referenceDocumentCount: 0,
            targetTokenCount: 20,
            referenceTokenCount: 0,
            rows: [
                ClusterRow(
                    phrase: "alpha beta",
                    n: 2,
                    frequency: 4,
                    normalizedFrequency: 2_000,
                    range: 1,
                    rangePercentage: 100,
                    referenceFrequency: nil,
                    referenceNormalizedFrequency: nil,
                    referenceRange: nil,
                    logRatio: nil
                )
            ]
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.cluster.query = ""
        workspace.cluster.selectedN = "2"

        await workspace.runCluster()
        XCTAssertEqual(repository.runClusterCallCount, 1)
        XCTAssertEqual(workspace.selectedTab, .cluster)
        XCTAssertEqual(workspace.currentExportSnapshot?.table.storageKey, "cluster")

        await workspace.openClusterKWIC()

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(repository.lastRunKWICSearchOptions.matchMode, .phraseExact)
        XCTAssertEqual(workspace.kwic.keyword, "alpha beta")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }
}
