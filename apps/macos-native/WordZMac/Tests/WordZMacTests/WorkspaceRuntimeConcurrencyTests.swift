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
