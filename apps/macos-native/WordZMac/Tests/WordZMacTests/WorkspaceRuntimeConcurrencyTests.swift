import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceRuntimeConcurrencyTests: XCTestCase {
    func testRapidKWICRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.kwicDelayNanoseconds = 120_000_000
        repository.kwicResultProvider = { keyword in
            KWICResult(json: [
                "rows": [[
                    "sentenceId": 0,
                    "sentenceTokenIndex": 0,
                    "left": "left",
                    "node": keyword,
                    "right": "right"
                ]]
            ])
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.kwic.keyword = "alpha"
        dispatcher.handleKWICAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.kwic.keyword = "beta"
        dispatcher.handleKWICAction(.run)
        try? await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertEqual(repository.runKWICCallCount, 2)
        XCTAssertEqual(repository.lastRunKWICKeyword, "beta")
        XCTAssertEqual(workspace.kwic.scene?.rows.first?.keyword, "beta")
        XCTAssertEqual(
            workspace.sceneGraph.kwic.tableSnapshot.rows.first?.value(for: KWICColumnKey.keyword.rawValue),
            "beta"
        )
        XCTAssertEqual(repository.savedWorkspaceDrafts.count, 1)
        XCTAssertTrue(repository.savedWorkspaceDrafts.allSatisfy { $0.currentTab == WorkspaceDetailTab.kwic.snapshotValue })
        XCTAssertFalse(workspace.runningTaskKeys.contains(.kwic))
    }

    func testRapidCompareRunsOnlyApplyLatestResult() async {
        let corpora = [
            makeCompareCorpus(id: "corpus-1", name: "Corpus A"),
            makeCompareCorpus(id: "corpus-2", name: "Corpus B"),
            makeCompareCorpus(id: "corpus-3", name: "Corpus C")
        ]
        let bootstrapState = makeBootstrapState(
            workspaceSnapshot: makeWorkspaceSnapshot(searchQuery: ""),
            corpora: corpora
        )
        let repository = FakeWorkspaceRepository(
            bootstrapState: bootstrapState,
            openedCorporaByID: [
                "corpus-1": makeOpenedCorpus(path: "/tmp/corpus-a.txt", displayName: "Corpus A", content: "alpha focus"),
                "corpus-2": makeOpenedCorpus(path: "/tmp/corpus-b.txt", displayName: "Corpus B", content: "beta contrast"),
                "corpus-3": makeOpenedCorpus(path: "/tmp/corpus-c.txt", displayName: "Corpus C", content: "gamma contrast")
            ]
        )
        repository.compareDelayNanoseconds = 120_000_000
        repository.compareResultProvider = { entries in
            makeCompareResult(
                marker: entries.map(\.corpusId).sorted().joined(separator: "+"),
                entries: entries
            )
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.compare.syncLibrarySnapshot(bootstrapState.librarySnapshot)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-2"]
        dispatcher.handleCompareAction(ComparePageAction.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-3"]
        dispatcher.handleCompareAction(ComparePageAction.run)
        try? await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertEqual(repository.runCompareCallCount, 2)
        XCTAssertEqual(workspace.compare.scene?.rows.first?.word, "corpus-1+corpus-3")
        XCTAssertEqual(
            workspace.sceneGraph.compare.tableSnapshot.rows.first?.value(for: CompareColumnKey.word.rawValue),
            "corpus-1+corpus-3"
        )
        XCTAssertEqual(repository.savedWorkspaceDrafts.count, 1)
        XCTAssertTrue(repository.savedWorkspaceDrafts.allSatisfy { $0.currentTab == WorkspaceDetailTab.compare.snapshotValue })
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.compare))
    }

    func testStatsAndWordRunsShareLatestFrequencyResult() async {
        let repository = makeTwoCorpusRepository()
        repository.statsDelayNanoseconds = 120_000_000
        repository.statsResultProvider = { text in
            makeStatsResult(rowCount: text.contains("beta") ? 6 : 2)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleStatsAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.sidebar.selectedCorpusID = "corpus-2"
        dispatcher.handleWordAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runStatsCallCount, 2)
        XCTAssertEqual(repository.lastRunStatsText, "beta focus")
        XCTAssertEqual(workspace.stats.result?.tokenCount, 60)
        XCTAssertEqual(workspace.word.result?.tokenCount, 60)
        XCTAssertEqual(workspace.word.scene?.totalRows, 6)
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.word.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.stats))
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.word))
    }

    func testRapidTokenizeRunsOnlyApplyLatestResult() async {
        let repository = makeTwoCorpusRepository()
        repository.tokenizeDelayNanoseconds = 120_000_000
        repository.tokenizeResultProvider = { text in
            makeTokenizeResult(marker: text.contains("beta") ? "beta" : "alpha")
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleTokenizeAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.sidebar.selectedCorpusID = "corpus-2"
        dispatcher.handleTokenizeAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runTokenizeCallCount, 2)
        XCTAssertEqual(repository.lastRunTokenizeText, "beta focus")
        XCTAssertEqual(workspace.tokenize.result?.tokens.first?.normalized, "beta")
        XCTAssertEqual(workspace.tokenize.scene?.rows.first?.normalized, "beta")
        XCTAssertEqual(
            workspace.sceneGraph.tokenize.tableSnapshot.rows.first?.value(for: TokenizeColumnKey.normalized.rawValue),
            "beta"
        )
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.tokenize.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.tokenize))
    }

    func testRapidChiSquareRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.chiSquareDelayNanoseconds = 120_000_000
        repository.chiSquareResultProvider = { a, b, c, d, yates in
            makeChiSquareResult(chiSquare: Double(a), total: a + b + c + d, yates: yates)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.chiSquare.a = "1"
        workspace.chiSquare.b = "2"
        workspace.chiSquare.c = "3"
        workspace.chiSquare.d = "4"
        workspace.chiSquare.useYates = false
        dispatcher.handleChiSquareAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.chiSquare.a = "9"
        workspace.chiSquare.b = "8"
        workspace.chiSquare.c = "7"
        workspace.chiSquare.d = "6"
        workspace.chiSquare.useYates = true
        dispatcher.handleChiSquareAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runChiSquareCallCount, 2)
        XCTAssertEqual(repository.lastRunChiSquareInputs?.a, 9)
        XCTAssertEqual(repository.lastRunChiSquareInputs?.yates, true)
        XCTAssertEqual(workspace.chiSquare.scene?.metrics.first(where: { $0.id == "chi" })?.value, "9")
        XCTAssertEqual(workspace.chiSquare.scene?.metrics.first(where: { $0.id == "n" })?.value, "30")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.chiSquare.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.chiSquare))
    }

    func testRapidLocatorRunsOnlyApplyLatestResult() async {
        let repository = makeTwoCorpusRepository()
        repository.locatorDelayNanoseconds = 120_000_000
        repository.locatorResultProvider = { _, sentenceId, nodeIndex, _, _ in
            makeLocatorResult(sentenceId: sentenceId, nodeIndex: nodeIndex, marker: "locator-\(sentenceId)")
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        workspace.locator.leftWindow = "3"
        workspace.locator.rightWindow = "4"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.locator.updateSource(LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 1))
        dispatcher.handleLocatorAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.locator.updateSource(LocatorSource(keyword: "node", sentenceId: 2, nodeIndex: 2))
        dispatcher.handleLocatorAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runLocatorCallCount, 2)
        XCTAssertEqual(repository.lastRunLocatorSentenceId, 2)
        XCTAssertEqual(repository.lastRunLocatorNodeIndex, 2)
        XCTAssertEqual(repository.lastRunLocatorLeftWindow, 3)
        XCTAssertEqual(repository.lastRunLocatorRightWindow, 4)
        XCTAssertEqual(workspace.locator.currentSource?.sentenceId, 2)
        XCTAssertEqual(workspace.locator.result?.rows.first?.text, "locator-2")
        XCTAssertEqual(workspace.locator.scene?.rows.first?.text, "locator-2")
        XCTAssertEqual(
            workspace.sceneGraph.locator.tableSnapshot.rows.first?.value(for: LocatorColumnKey.text.rawValue),
            "locator-2"
        )
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.locator.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.locator))
    }

    func testRapidTopicsRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.topicsDelayNanoseconds = 120_000_000
        repository.topicsResultProvider = { _, options in
            makeTopicAnalysisResult(marker: options.searchQuery.isEmpty ? "empty" : options.searchQuery)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.topics.query = "alpha"
        dispatcher.handleTopicsAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.topics.query = "beta"
        dispatcher.handleTopicsAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runTopicsCallCount, 2)
        XCTAssertEqual(repository.lastRunTopicsOptions?.searchQuery, "beta")
        XCTAssertEqual(workspace.topics.result?.clusters.first?.keywordCandidates.first?.term, "beta")
        XCTAssertEqual(workspace.topics.scene?.clusters.first?.keywordsText.contains("beta"), true)
        XCTAssertEqual(repository.savedWorkspaceDrafts.count, 1)
        XCTAssertTrue(repository.savedWorkspaceDrafts.allSatisfy { $0.currentTab == WorkspaceDetailTab.topics.snapshotValue })
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.topics))
    }

    func testRapidSentimentRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.sentimentDelayNanoseconds = 120_000_000
        repository.sentimentResultProvider = { request in
            let marker = request.texts.first?.text.contains("beta") == true ? "beta" : "alpha"
            return makeSentimentResult(request: request, marker: marker)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.sentiment.handle(.changeSource(.pastedText))
        workspace.sentiment.handle(.changeManualText("alpha is good."))
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.sentiment.handle(.changeManualText("beta is good."))
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 2)
        XCTAssertEqual(repository.lastSentimentRequest?.texts.first?.text, "beta is good.")
        XCTAssertEqual(workspace.sentiment.rawResult?.request.texts.first?.text, "beta is good.")
        XCTAssertEqual(workspace.sentiment.scene?.rows.first?.text, "beta is good.")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.sentiment.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.sentiment))
    }

    func testRapidTopicSegmentSentimentRunsOnlyApplyLatestResult() async {
        let fixture = makeTopicsSourceReaderFixture()
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            tokenizeResult: fixture.tokenizeResult,
            topicsResult: fixture.topicsResult
        )
        repository.sentimentDelayNanoseconds = 120_000_000
        repository.sentimentResultProvider = { request in
            let marker = request.texts.first?.groupID == TopicAnalysisResult.outlierTopicID ? "outlier" : "topic"
            return makeSentimentResult(request: request, marker: marker)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        workspace.topics.query = ""
        workspace.topics.apply(fixture.topicsResult)
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()
        workspace.sentiment.handle(.changeSource(.topicSegments))
        workspace.sentiment.unit = .sourceSentence
        workspace.sentiment.contextBasis = .fullSentenceWhenAvailable
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.sentiment.topicSegmentsFocusClusterID = "topic-1"
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.sentiment.topicSegmentsFocusClusterID = TopicAnalysisResult.outlierTopicID
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 360_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 2)
        XCTAssertEqual(repository.lastSentimentRequest?.source, .topicSegments)
        XCTAssertEqual(repository.lastSentimentRequest?.texts.first?.groupID, TopicAnalysisResult.outlierTopicID)
        XCTAssertEqual(workspace.sentiment.rawResult?.request.texts.first?.groupID, TopicAnalysisResult.outlierTopicID)
        XCTAssertEqual(workspace.sentiment.scene?.rows.first?.text, "outlier is good.")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.sentiment.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.sentiment))
    }

    func testRapidPlotRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.plotDelayNanoseconds = 120_000_000
        repository.plotResultProvider = { request in
            makePlotResult(query: request.query, scope: request.scope, searchOptions: request.searchOptions, rows: [
                makePlotRow(marker: request.query)
            ])
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.plot.query = "alpha"
        dispatcher.handlePlotAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.plot.query = "beta"
        dispatcher.handlePlotAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runPlotCallCount, 2)
        XCTAssertEqual(repository.lastRunPlotRequest?.query, "beta")
        XCTAssertEqual(workspace.plot.result?.request.query, "beta")
        XCTAssertEqual(workspace.plot.scene?.query, "beta")
        XCTAssertEqual(workspace.plot.scene?.rows.first?.displayName, "beta corpus")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.plot.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.plot))
    }

    func testRapidNgramRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.ngramDelayNanoseconds = 120_000_000
        repository.ngramResultProvider = { _, n in
            NgramResult(n: n, rows: [NgramRow(phrase: "ngram-\(n)", count: n)])
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.ngram.ngramSize = "2"
        dispatcher.handleNgramAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.ngram.ngramSize = "3"
        dispatcher.handleNgramAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runNgramCallCount, 2)
        XCTAssertEqual(repository.lastRunNgramN, 3)
        XCTAssertEqual(workspace.ngram.result?.n, 3)
        XCTAssertEqual(workspace.ngram.result?.rows.first?.phrase, "ngram-3")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.ngram.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.ngram))
    }

    func testRapidClusterRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.clusterDelayNanoseconds = 120_000_000
        repository.clusterResultProvider = { request in
            makeClusterResult(marker: request.caseSensitive ? "case-sensitive" : "case-insensitive")
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.cluster.caseSensitive = false
        dispatcher.handleClusterAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.cluster.caseSensitive = true
        dispatcher.handleClusterAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runClusterCallCount, 2)
        XCTAssertEqual(repository.lastRunClusterRequest?.caseSensitive, true)
        XCTAssertEqual(workspace.cluster.result?.rows.first?.phrase, "case-sensitive")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.cluster.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.cluster))
    }

    func testRapidCollocateRunsOnlyApplyLatestResult() async {
        let repository = FakeWorkspaceRepository()
        repository.collocateDelayNanoseconds = 120_000_000
        repository.collocateResultProvider = { keyword in
            makeCollocateResult(marker: keyword)
        }

        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        repository.savedWorkspaceDrafts = []
        workspace.sidebar.selectedCorpusID = "corpus-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        workspace.collocate.keyword = "alpha"
        dispatcher.handleCollocateAction(.run)
        try? await Task.sleep(nanoseconds: 20_000_000)

        workspace.collocate.keyword = "beta"
        dispatcher.handleCollocateAction(.run)
        try? await Task.sleep(nanoseconds: 340_000_000)

        XCTAssertEqual(repository.runCollocateCallCount, 2)
        XCTAssertEqual(repository.lastRunCollocateKeyword, "beta")
        XCTAssertEqual(workspace.collocate.result?.rows.first?.word, "beta-neighbor")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.collocate.snapshotValue)
        XCTAssertFalse(workspace.runningTaskKeys.contains(WorkspaceRuntimeTaskKey.collocate))
    }

    func testPersistenceActorDoesNotApplyStaleCompletionCallbacks() async {
        var savedTabs: [String] = []
        var persistedTabs: [String] = []
        let actor = WorkspacePersistenceActor { draft in
            savedTabs.append(draft.currentTab)
            if draft.currentTab == "stats" {
                try? await Task.sleep(nanoseconds: 120_000_000)
            }
        }

        await actor.schedule(
            draft: makeDraft(currentTab: "stats"),
            strategy: .immediate,
            onPersisted: { draft in
                persistedTabs.append(draft.currentTab)
            },
            onError: { _ in
                XCTFail("unexpected save failure")
            }
        )
        try? await Task.sleep(nanoseconds: 20_000_000)
        await actor.schedule(
            draft: makeDraft(currentTab: "kwic"),
            strategy: .immediate,
            onPersisted: { draft in
                persistedTabs.append(draft.currentTab)
            },
            onError: { _ in
                XCTFail("unexpected save failure")
            }
        )
        try? await Task.sleep(nanoseconds: 260_000_000)

        XCTAssertEqual(savedTabs, ["stats", "kwic"])
        XCTAssertEqual(persistedTabs, ["kwic"])
    }
}

private func makeCompareCorpus(id: String, name: String) -> LibraryCorpusItem {
    LibraryCorpusItem(json: [
        "id": id,
        "name": name,
        "folderId": "folder-1",
        "folderName": "Default",
        "sourceType": "txt",
        "representedPath": "/tmp/\(id).txt",
        "metadata": [:]
    ])
}

@MainActor
private func makeTwoCorpusRepository() -> FakeWorkspaceRepository {
    let corpora = [
        makeCompareCorpus(id: "corpus-1", name: "Corpus A"),
        makeCompareCorpus(id: "corpus-2", name: "Corpus B")
    ]
    let bootstrapState = makeBootstrapState(
        workspaceSnapshot: makeWorkspaceSnapshot(searchQuery: ""),
        corpora: corpora
    )
    return FakeWorkspaceRepository(
        bootstrapState: bootstrapState,
        openedCorporaByID: [
            "corpus-1": makeOpenedCorpus(path: "/tmp/corpus-a.txt", displayName: "Corpus A", content: "alpha focus"),
            "corpus-2": makeOpenedCorpus(path: "/tmp/corpus-b.txt", displayName: "Corpus B", content: "beta focus")
        ]
    )
}

private func makeOpenedCorpus(
    path: String,
    displayName: String,
    content: String
) -> OpenedCorpus {
    OpenedCorpus(json: [
        "mode": "saved",
        "filePath": path,
        "displayName": displayName,
        "content": content,
        "sourceType": "txt"
    ])
}

private func makeTokenizeResult(marker: String) -> TokenizeResult {
    TokenizeResult(
        sentences: [
            TokenizedSentence(
                sentenceId: 0,
                text: "\(marker) focus.",
                tokens: [
                    TokenizedToken(
                        original: marker,
                        normalized: marker,
                        sentenceId: 0,
                        tokenIndex: 0,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: marker, lexicalClass: .noun)
                    )
                ]
            )
        ]
    )
}

private func makeChiSquareResult(chiSquare: Double, total: Int, yates: Bool) -> ChiSquareResult {
    ChiSquareResult(json: [
        "observed": [[12, 30], [6, 40]],
        "expected": [[8.6, 33.4], [9.4, 36.6]],
        "rowTotals": [42, 46],
        "colTotals": [18, 70],
        "total": total,
        "chiSquare": chiSquare,
        "degreesOfFreedom": 1,
        "pValue": 0.0978,
        "significantAt05": false,
        "significantAt01": false,
        "phi": 0.1765,
        "oddsRatio": 2.6667,
        "yatesCorrection": yates,
        "warnings": []
    ])
}

private func makeLocatorResult(sentenceId: Int, nodeIndex: Int, marker: String) -> LocatorResult {
    LocatorResult(
        sentenceCount: 1,
        rows: [
            LocatorRow(
                sentenceId: sentenceId,
                text: marker,
                leftWords: "left",
                nodeWord: "node-\(nodeIndex)",
                rightWords: "right",
                status: "当前定位"
            )
        ]
    )
}

private func makeCompareResult(
    marker: String,
    entries: [CompareRequestEntry]
) -> CompareResult {
    CompareResult(json: [
        "corpora": entries.enumerated().map { index, entry in
            [
                "corpusId": entry.corpusId,
                "corpusName": entry.corpusName,
                "folderName": entry.folderName,
                "tokenCount": 100 + index,
                "typeCount": 50 + index,
                "ttr": 0.5,
                "sttr": 0.45,
                "topWord": marker,
                "topWordCount": 10 + index
            ]
        },
        "rows": [[
            "word": marker,
            "total": 18,
            "spread": entries.count,
            "range": 3.2,
            "dominantCorpusName": entries.last?.corpusName ?? "",
            "keyness": 4.21,
            "effectSize": 0.58,
            "pValue": 0.04,
            "referenceNormFreq": 666.7,
            "perCorpus": entries.enumerated().map { index, entry in
                [
                    "corpusId": entry.corpusId,
                    "corpusName": entry.corpusName,
                    "folderName": entry.folderName,
                    "count": 10 - index,
                    "tokenCount": 100 + index,
                    "normFreq": 900.0 - Double(index * 100)
                ]
            }
        ]]
    ])
}

private func makePlotRow(marker: String) -> PlotRow {
    PlotRow(
        id: marker,
        corpusId: "corpus-1",
        fileID: 0,
        filePath: "/tmp/\(marker).txt",
        displayName: "\(marker) corpus",
        fileTokens: 120,
        frequency: 3,
        normalizedFrequency: 250,
        hitMarkers: [
            PlotHitMarker(id: "\(marker)-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0)
        ]
    )
}

private func makeClusterResult(marker: String) -> ClusterResult {
    ClusterResult(
        mode: .targetOnly,
        targetDocumentCount: 1,
        referenceDocumentCount: 0,
        targetTokenCount: 100,
        referenceTokenCount: 0,
        rows: [
            ClusterRow(
                phrase: marker,
                n: 3,
                frequency: 3,
                normalizedFrequency: 300,
                range: 1,
                rangePercentage: 100,
                referenceFrequency: nil,
                referenceNormalizedFrequency: nil,
                referenceRange: nil,
                logRatio: nil
            )
        ]
    )
}

private func makeCollocateResult(marker: String) -> CollocateResult {
    CollocateResult(rows: [
        CollocateRow(
            word: "\(marker)-neighbor",
            total: 3,
            left: 1,
            right: 2,
            wordFreq: 10,
            keywordFreq: 5,
            rate: 0.3,
            logDice: 8.0,
            mutualInformation: 2.1,
            tScore: 4.2
        )
    ])
}

private func makeDraft(currentTab: String) -> WorkspaceStateDraft {
    let empty = WorkspaceStateDraft.empty
    return WorkspaceStateDraft(
        currentTab: currentTab,
        currentLibraryFolderId: empty.currentLibraryFolderId,
        selectedCorpusSetID: empty.selectedCorpusSetID,
        corpusIds: empty.corpusIds,
        corpusNames: empty.corpusNames,
        searchQuery: empty.searchQuery,
        searchOptions: empty.searchOptions,
        stopwordFilter: empty.stopwordFilter,
        annotationProfile: empty.annotationProfile,
        annotationLexicalClasses: empty.annotationLexicalClasses,
        annotationScripts: empty.annotationScripts,
        tokenizeLanguagePreset: empty.tokenizeLanguagePreset,
        tokenizeLemmaStrategy: empty.tokenizeLemmaStrategy,
        compareReferenceCorpusID: empty.compareReferenceCorpusID,
        compareSelectedCorpusIDs: empty.compareSelectedCorpusIDs,
        sentimentSource: empty.sentimentSource,
        sentimentUnit: empty.sentimentUnit,
        sentimentContextBasis: empty.sentimentContextBasis,
        sentimentBackend: empty.sentimentBackend,
        sentimentDomainPackID: empty.sentimentDomainPackID,
        sentimentRuleProfileID: empty.sentimentRuleProfileID,
        sentimentCalibrationProfileID: empty.sentimentCalibrationProfileID,
        sentimentChartKind: empty.sentimentChartKind,
        sentimentThresholdPreset: empty.sentimentThresholdPreset,
        sentimentDecisionThreshold: empty.sentimentDecisionThreshold,
        sentimentMinimumEvidence: empty.sentimentMinimumEvidence,
        sentimentNeutralBias: empty.sentimentNeutralBias,
        sentimentRowFilterQuery: empty.sentimentRowFilterQuery,
        sentimentLabelFilter: empty.sentimentLabelFilter,
        sentimentReviewFilter: empty.sentimentReviewFilter,
        sentimentReviewStatusFilter: empty.sentimentReviewStatusFilter,
        sentimentShowOnlyHardCases: empty.sentimentShowOnlyHardCases,
        sentimentWorkspaceCalibrationProfile: empty.sentimentWorkspaceCalibrationProfile,
        sentimentImportedLexiconBundles: empty.sentimentImportedLexiconBundles,
        sentimentSelectedCorpusIDs: empty.sentimentSelectedCorpusIDs,
        sentimentReferenceCorpusID: empty.sentimentReferenceCorpusID,
        keywordActiveTab: empty.keywordActiveTab,
        keywordSuiteConfiguration: empty.keywordSuiteConfiguration,
        keywordTargetCorpusID: empty.keywordTargetCorpusID,
        keywordReferenceCorpusID: empty.keywordReferenceCorpusID,
        keywordLowercased: empty.keywordLowercased,
        keywordRemovePunctuation: empty.keywordRemovePunctuation,
        keywordMinimumFrequency: empty.keywordMinimumFrequency,
        keywordStatistic: empty.keywordStatistic,
        keywordStopwordFilter: empty.keywordStopwordFilter,
        plotQuery: empty.plotQuery,
        plotSearchOptions: empty.plotSearchOptions,
        ngramSize: empty.ngramSize,
        ngramPageSize: empty.ngramPageSize,
        clusterSelectedN: empty.clusterSelectedN,
        clusterMinFrequency: empty.clusterMinFrequency,
        clusterSortMode: empty.clusterSortMode,
        clusterCaseSensitive: empty.clusterCaseSensitive,
        clusterStopwordFilter: empty.clusterStopwordFilter,
        clusterPunctuationMode: empty.clusterPunctuationMode,
        clusterSelectedPhrase: empty.clusterSelectedPhrase,
        clusterPageSize: empty.clusterPageSize,
        clusterReferenceCorpusID: empty.clusterReferenceCorpusID,
        kwicLeftWindow: empty.kwicLeftWindow,
        kwicRightWindow: empty.kwicRightWindow,
        collocateLeftWindow: empty.collocateLeftWindow,
        collocateRightWindow: empty.collocateRightWindow,
        collocateMinFreq: empty.collocateMinFreq,
        topicsMinTopicSize: empty.topicsMinTopicSize,
        topicsKeywordDisplayCount: empty.topicsKeywordDisplayCount,
        topicsIncludeOutliers: empty.topicsIncludeOutliers,
        topicsPageSize: empty.topicsPageSize,
        topicsActiveTopicID: empty.topicsActiveTopicID,
        frequencyNormalizationUnit: empty.frequencyNormalizationUnit,
        frequencyRangeMode: empty.frequencyRangeMode,
        chiSquareA: empty.chiSquareA,
        chiSquareB: empty.chiSquareB,
        chiSquareC: empty.chiSquareC,
        chiSquareD: empty.chiSquareD,
        chiSquareUseYates: empty.chiSquareUseYates
    )
}
