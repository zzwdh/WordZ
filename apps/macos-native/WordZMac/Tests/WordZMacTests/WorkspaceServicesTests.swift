import XCTest
@testable import WordZWorkspaceCore

final class WorkspaceServicesTests: XCTestCase {
    func testWorkspacePersistenceBuildsDraftWithSelectedCorpusFallbacks() {
        let selectedCorpus = LibraryCorpusItem(json: [
            "id": "corpus-1",
            "name": "Demo Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt"
        ])

        let draft = WorkspacePersistenceService().buildDraft(
            selectedTab: .kwic,
            selectedFolderID: "folder-1",
            selectedCorpusSetID: "set-1",
            selectedCorpus: selectedCorpus,
            openedCorpus: nil,
            searchQuery: "keyword",
            searchOptions: SearchOptionsState(words: false, caseSensitive: true, regex: true),
            stopwordFilter: StopwordFilterState(enabled: true, mode: .include, listText: "alpha\nbeta"),
            tokenizeLanguagePreset: .cjkFocused,
            tokenizeLemmaStrategy: .lemmaPreferred,
            ngramSize: "3",
            ngramPageSize: "100",
            kwicLeftWindow: "3",
            kwicRightWindow: "4",
            collocateLeftWindow: "5",
            collocateRightWindow: "6",
            collocateMinFreq: "2",
            topicsMinTopicSize: "3",
            topicsKeywordDisplayCount: "7",
            topicsIncludeOutliers: true,
            topicsPageSize: "50",
            topicsActiveTopicID: "topic-1",
            chiSquareA: "4",
            chiSquareB: "8",
            chiSquareC: "6",
            chiSquareD: "10",
            chiSquareUseYates: true
        )

        XCTAssertEqual(draft.currentTab, WorkspaceDetailTab.kwic.snapshotValue)
        XCTAssertEqual(draft.currentLibraryFolderId, "folder-1")
        XCTAssertEqual(draft.selectedCorpusSetID, "set-1")
        XCTAssertEqual(draft.corpusIds, ["corpus-1"])
        XCTAssertEqual(draft.corpusNames, ["Demo Corpus"])
        XCTAssertEqual(draft.searchQuery, "keyword")
        XCTAssertEqual(draft.searchOptions, SearchOptionsState(words: false, caseSensitive: true, regex: true))
        XCTAssertEqual(draft.stopwordFilter.mode, StopwordFilterMode.include)
        XCTAssertEqual(draft.stopwordFilter.parsedWords, ["alpha", "beta"])
        XCTAssertEqual(draft.tokenizeLanguagePreset, .cjkFocused)
        XCTAssertEqual(draft.tokenizeLemmaStrategy, .lemmaPreferred)
        XCTAssertEqual(draft.ngramSize, "3")
        XCTAssertEqual(draft.ngramPageSize, "100")
        XCTAssertEqual(draft.collocateMinFreq, "2")
        XCTAssertEqual(draft.topicsMinTopicSize, "3")
        XCTAssertEqual(draft.topicsKeywordDisplayCount, "7")
        XCTAssertTrue(draft.topicsIncludeOutliers)
        XCTAssertEqual(draft.topicsPageSize, "50")
        XCTAssertEqual(draft.topicsActiveTopicID, "topic-1")
        XCTAssertEqual(draft.chiSquareA, "4")
        XCTAssertEqual(draft.chiSquareD, "10")
        XCTAssertTrue(draft.chiSquareUseYates)
    }

    func testWorkspacePersistenceBuildsDraftWithSentimentState() {
        let draft = WorkspacePersistenceService().buildDraft(
            selectedTab: .sentiment,
            selectedFolderID: "folder-1",
            selectedCorpusSetID: "",
            selectedCorpus: nil,
            openedCorpus: nil,
            searchQuery: "",
            searchOptions: .default,
            stopwordFilter: .default,
            sentimentSource: .corpusCompare,
            sentimentUnit: .document,
            sentimentContextBasis: .fullSentenceWhenAvailable,
            sentimentBackend: .coreML,
            sentimentChartKind: .trendLine,
            sentimentThresholdPreset: .balanced,
            sentimentDecisionThreshold: 0.25,
            sentimentMinimumEvidence: 0.6,
            sentimentNeutralBias: 1.0,
            sentimentRowFilterQuery: "good",
            sentimentLabelFilter: .positive,
            sentimentSelectedCorpusIDs: ["corpus-1"],
            sentimentReferenceCorpusID: "corpus-2",
            ngramSize: "2",
            ngramPageSize: "10",
            kwicLeftWindow: "5",
            kwicRightWindow: "5",
            collocateLeftWindow: "5",
            collocateRightWindow: "5",
            collocateMinFreq: "1",
            topicsMinTopicSize: "2",
            topicsIncludeOutliers: true,
            topicsPageSize: "50",
            topicsActiveTopicID: "",
            chiSquareA: "",
            chiSquareB: "",
            chiSquareC: "",
            chiSquareD: "",
            chiSquareUseYates: false
        )

        XCTAssertEqual(draft.currentTab, WorkspaceDetailTab.sentiment.snapshotValue)
        XCTAssertEqual(draft.sentimentSource, .corpusCompare)
        XCTAssertEqual(draft.sentimentUnit, .document)
        XCTAssertEqual(draft.sentimentContextBasis, .fullSentenceWhenAvailable)
        XCTAssertEqual(draft.sentimentBackend, .coreML)
        XCTAssertEqual(draft.sentimentChartKind, .trendLine)
        XCTAssertEqual(draft.sentimentThresholdPreset, .balanced)
        XCTAssertEqual(draft.sentimentDecisionThreshold, 0.25, accuracy: 0.0001)
        XCTAssertEqual(draft.sentimentMinimumEvidence, 0.6, accuracy: 0.0001)
        XCTAssertEqual(draft.sentimentNeutralBias, 1.0, accuracy: 0.0001)
        XCTAssertEqual(draft.sentimentRowFilterQuery, "good")
        XCTAssertEqual(draft.sentimentLabelFilter, .positive)
        XCTAssertEqual(draft.sentimentSelectedCorpusIDs, ["corpus-1"])
        XCTAssertEqual(draft.sentimentReferenceCorpusID, "corpus-2")
    }

    func testWorkspacePresentationBuildsRepresentedPathAndSummary() {
        let appInfo = AppInfoSummary(json: [
            "name": "WordZ",
            "version": "1.1.0",
            "help": [],
            "releaseNotes": [],
            "userDataDir": "/tmp/wordz"
        ])
        let corpus = LibraryCorpusItem(json: [
            "id": "corpus-1",
            "name": "Saved Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt"
        ])
        let opened = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/corpus.txt",
            "displayName": "Opened Corpus",
            "content": "hello world",
            "sourceType": "txt"
        ])
        let snapshot = WorkspaceSnapshotSummary(json: [
            "workspace": ["corpusNames": ["Opened Corpus"]]
        ])

        let presentation = WorkspacePresentationService().buildPresentation(
            appInfo: appInfo,
            selectedCorpus: corpus,
            openedCorpus: opened,
            workspaceSnapshot: snapshot
        )

        XCTAssertEqual(presentation.displayName, "Opened Corpus")
        XCTAssertEqual(presentation.representedPath, "/tmp/corpus.txt")
        XCTAssertEqual(presentation.workspaceSummary, "工作区：Opened Corpus ｜ 当前语料：Opened Corpus")
    }

    @MainActor
    func testWorkspaceSessionStoreTracksRestoreAndEditedState() {
        let store = WorkspaceSessionStore()
        let snapshot = WorkspaceSnapshotSummary(json: [:])
        let corpus = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/corpus.txt",
            "displayName": "Opened Corpus",
            "content": "hello world",
            "sourceType": "txt"
        ])

        store.applyBootstrap(snapshot: snapshot)
        XCTAssertEqual(store.workspaceSnapshot?.currentTab, "stats")

        store.beginRestore()
        store.markEdited()
        XCTAssertFalse(store.isDocumentEdited)

        store.finishRestore()
        store.setOpenedCorpus(corpus, sourceID: "corpus-1")
        XCTAssertTrue(store.matchesOpenedCorpusSource("corpus-1"))

        store.markEdited()
        XCTAssertTrue(store.isDocumentEdited)

        let draft = WorkspaceStateDraft(
            currentTab: WorkspaceDetailTab.kwic.snapshotValue,
            currentLibraryFolderId: "folder-1",
            corpusIds: ["corpus-1"],
            corpusNames: ["Opened Corpus"],
            searchQuery: "keyword",
            searchOptions: .default,
            stopwordFilter: .default,
            ngramSize: "2",
            ngramPageSize: "10",
            kwicLeftWindow: "3",
            kwicRightWindow: "4",
            collocateLeftWindow: "5",
            collocateRightWindow: "6",
            collocateMinFreq: "2",
            topicsMinTopicSize: "3",
            topicsIncludeOutliers: true,
            topicsPageSize: "50",
            topicsActiveTopicID: "topic-1",
            chiSquareA: "10",
            chiSquareB: "20",
            chiSquareC: "5",
            chiSquareD: "15",
            chiSquareUseYates: true
        )
        store.applySavedDraft(draft)
        XCTAssertFalse(store.isDocumentEdited)
        XCTAssertEqual(store.workspaceSnapshot?.corpusIds, ["corpus-1"])
        XCTAssertEqual(store.workspaceSnapshot?.chiSquareA, "10")
        XCTAssertTrue(store.workspaceSnapshot?.chiSquareUseYates ?? false)

        store.resetToEmptyWorkspace()
        XCTAssertEqual(store.workspaceSnapshot?.currentTab, WorkspaceDetailTab.stats.snapshotValue)
        XCTAssertFalse(store.isDocumentEdited)
        XCTAssertNil(store.openedCorpus)

        store.resetOpenedCorpus()
        XCTAssertFalse(store.matchesOpenedCorpusSource("corpus-1"))
    }

    @MainActor
    func testWorkspaceSceneGraphStoreSyncsResultNodes() {
        let store = WorkspaceSceneGraphStore()
        let statsScene = StatsSceneBuilder().build(
            from: StatsResult(json: [
                "tokenCount": 2,
                "typeCount": 2,
                "ttr": 1.0,
                "sttr": 1.0,
                "freqRows": [["alpha", 1], ["beta", 1]]
            ]),
            sortMode: .frequencyDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(StatsColumnKey.allCases)
        )

        store.sync(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: statsScene,
            topics: nil,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )

        XCTAssertEqual(store.graph.activeTab, .stats)
        XCTAssertTrue(store.graph.stats.hasResult)
        XCTAssertEqual(store.graph.stats.totalRows, 2)
        XCTAssertEqual(store.graph.stats.status, "显示 2 / 2")
        XCTAssertFalse(store.graph.kwic.hasResult)
        XCTAssertFalse(store.graph.compare.hasResult)
    }

    @MainActor
    func testWorkspaceSceneGraphStoreSyncResultUpdatesOnlySelectedNode() {
        let store = WorkspaceSceneGraphStore()
        let statsScene = StatsSceneBuilder().build(
            from: makeStatsResult(rowCount: 2),
            sortMode: .frequencyDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(StatsColumnKey.allCases)
        )
        let kwicViewModel = KWICPageViewModel()
        kwicViewModel.apply(makeKWICResult(rowCount: 3))

        store.sync(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: statsScene,
            topics: nil,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )

        store.syncResult(
            activeTab: .kwic,
            resultTab: .kwic,
            stats: nil,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: kwicViewModel.scene,
            collocate: nil,
            locator: nil
        )

        XCTAssertTrue(store.graph.stats.hasResult)
        XCTAssertEqual(store.graph.stats.totalRows, 2)
        XCTAssertTrue(store.graph.kwic.hasResult)
        XCTAssertEqual(store.graph.kwic.totalRows, 3)
    }

    @MainActor
    func testWorkspaceSceneGraphStoreSkipsRevisionBumpForIdenticalResultSync() {
        let store = WorkspaceSceneGraphStore()
        let shell = WorkspaceShellSceneModel(
            workspaceSummary: "工作区：空",
            buildSummary: "SwiftUI + Node.js sidecar",
            toolbar: WorkspaceToolbarSceneModel(items: [])
        )
        let statsScene = StatsSceneBuilder().build(
            from: makeStatsResult(rowCount: 2),
            sortMode: .frequencyDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(StatsColumnKey.allCases)
        )

        store.sync(
            context: .empty,
            sidebar: .empty,
            shell: shell,
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: statsScene,
            topics: nil,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )
        let revisionAfterInitialSync = store.graphRevision

        store.syncResult(
            shell: shell,
            activeTab: .stats,
            resultTab: .stats,
            stats: statsScene,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )

        XCTAssertEqual(store.graphRevision, revisionAfterInitialSync)
    }

    @MainActor
    func testWorkspaceSceneGraphStoreSyncResultUpdatesSentimentNode() {
        let store = WorkspaceSceneGraphStore()
        let statsScene = StatsSceneBuilder().build(
            from: makeStatsResult(rowCount: 2),
            sortMode: .frequencyDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(StatsColumnKey.allCases)
        )
        let sentimentScene = SentimentSceneBuilder().build(
            from: makeSentimentResult(),
            thresholdPreset: .conservative,
            filterQuery: "",
            labelFilter: nil,
            sortMode: .original,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: SentimentPageViewModel.defaultVisibleColumns,
            selectedRowID: nil,
            chartKind: .distributionBar
        )

        store.sync(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: statsScene,
            topics: nil,
            compare: nil,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )

        store.syncResult(
            activeTab: .sentiment,
            resultTab: .sentiment,
            stats: nil,
            compare: nil,
            sentiment: sentimentScene,
            chiSquare: nil,
            ngram: nil,
            kwic: nil,
            collocate: nil,
            locator: nil
        )

        XCTAssertEqual(store.graph.activeTab, .sentiment)
        XCTAssertTrue(store.graph.sentiment.hasResult)
        XCTAssertEqual(store.graph.sentiment.totalRows, 2)
        XCTAssertEqual(store.graph.sentiment.visibleRows, 2)
    }

    func testLibrarySnapshotFallsBackToItemsPayload() {
        let snapshot = LibrarySnapshot(json: [
            "folders": [
                ["id": "uncategorized", "name": "未分类"]
            ],
            "items": [
                [
                    "id": "corpus-1",
                    "name": "Demo Corpus",
                    "folderId": "uncategorized",
                    "folderName": "未分类",
                    "sourceType": "txt"
                ]
            ]
        ])

        XCTAssertEqual(snapshot.folders.count, 1)
        XCTAssertEqual(snapshot.corpora.count, 1)
        XCTAssertEqual(snapshot.corpora.first?.name, "Demo Corpus")
    }

    func testNativeCorpusStoreReusesInMemoryManifestAfterInitialization() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-store-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        XCTAssertEqual(imported.importedCount, 1)
        XCTAssertEqual(try store.listLibrary().corpora.count, 1)

        let corporaURL = rootURL.appendingPathComponent("corpora.json")
        try Data("[]".utf8).write(to: corporaURL, options: .atomic)

        XCTAssertEqual(try store.listLibrary().corpora.count, 1)
    }

    func testNativeCorpusStorePersistsCorpusSetRoundTrip() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-corpus-set-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let importedCorpus = try XCTUnwrap(imported.importedItems.first)

        let savedSet = try store.saveCorpusSet(
            name: "课堂语料集",
            corpusIDs: [importedCorpus.id],
            metadataFilterState: CorpusMetadataFilterState(
                sourceQuery: "教材",
                yearFrom: "2020",
                yearTo: "2024",
                genreQuery: "",
                tagsQuery: "课堂"
            )
        )

        var snapshot = try store.listLibrary()
        XCTAssertEqual(snapshot.corpusSets.map(\.name), ["课堂语料集"])
        XCTAssertEqual(snapshot.corpusSets.first?.corpusIDs, [importedCorpus.id])
        XCTAssertEqual(snapshot.corpusSets.first?.metadataFilterState.sourceQuery, "教材")
        XCTAssertEqual(snapshot.corpusSets.first?.metadataFilterState.yearFrom, "2020")
        XCTAssertEqual(snapshot.corpusSets.first?.metadataFilterState.yearTo, "2024")

        try store.deleteCorpusSet(corpusSetID: savedSet.id)

        snapshot = try store.listLibrary()
        XCTAssertTrue(snapshot.corpusSets.isEmpty)
    }

    func testNativeCorpusStorePersistsConcordanceSavedSetRoundTrip() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-hit-set-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let savedSet = try store.saveConcordanceSavedSet(
            makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        )

        var sets = try store.listConcordanceSavedSets()
        XCTAssertEqual(sets.map(\.name), ["KWIC Set"])
        XCTAssertEqual(sets.first?.kind, .kwic)
        XCTAssertEqual(sets.first?.rows.count, 2)

        try store.deleteConcordanceSavedSet(setID: savedSet.id)

        sets = try store.listConcordanceSavedSets()
        XCTAssertTrue(sets.isEmpty)
    }

    func testNativeCorpusStorePersistsEvidenceItemRoundTrip() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-evidence-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let first = makeEvidenceItem(sourceKind: .kwic, reviewStatus: .pending)
        let second = EvidenceItem(
            id: "evidence-locator-keep-2",
            sourceKind: .locator,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-2",
            corpusName: "Locator Corpus",
            sentenceId: 4,
            sentenceTokenIndex: 5,
            leftContext: "left",
            keyword: "node",
            rightContext: "right",
            fullSentenceText: "left node right",
            citationText: "Sentence 5: left node right",
            query: "node",
            leftWindow: 5,
            rightWindow: 5,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .keep,
            note: "keep this",
            createdAt: "2026-04-13T00:00:00Z",
            updatedAt: "2026-04-13T00:00:00Z"
        )

        _ = try store.saveEvidenceItem(first)
        var savedSecond = try store.saveEvidenceItem(second)

        var items = try store.listEvidenceItems()
        XCTAssertEqual(items.map(\.id), [second.id, first.id])

        savedSecond.reviewStatus = .exclude
        savedSecond.note = "updated"
        _ = try store.saveEvidenceItem(savedSecond)

        try store.replaceEvidenceItems([first, savedSecond])

        items = try store.listEvidenceItems()
        XCTAssertEqual(items.map(\.id), [first.id, savedSecond.id])
        XCTAssertEqual(items.last?.reviewStatus, .exclude)
        XCTAssertEqual(items.last?.note, "updated")

        try store.deleteEvidenceItem(itemID: first.id)
        items = try store.listEvidenceItems()
        XCTAssertEqual(items.map(\.id), [savedSecond.id])
    }

    func testNativeCorpusStoreImportsCorporaIntoDBStorageFiles() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-db-store-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)

        let manifestData = try Data(contentsOf: rootURL.appendingPathComponent("corpora.json"))
        let manifest = try JSONSerialization.jsonObject(with: manifestData) as? [[String: Any]]
        let storageFileName = try XCTUnwrap(manifest?.first?["storageFileName"] as? String)
        XCTAssertTrue(storageFileName.hasSuffix(".db"))
        XCTAssertEqual(corpus.representedPath, sourceURL.path)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: rootURL.appendingPathComponent("corpora").appendingPathComponent(storageFileName).path
            )
        )

        let storedDocument = try XCTUnwrap(
            try NativeCorpusDatabaseSupport.readDocument(
                at: rootURL.appendingPathComponent("corpora").appendingPathComponent(storageFileName)
            )
        )
        XCTAssertEqual(storedDocument.metadata.schemaVersion, NativeCorpusDatabaseSupport.currentSchemaVersion)
        XCTAssertEqual(storedDocument.metadata.detectedEncoding, "utf-8")
        XCTAssertEqual(storedDocument.metadata.tokenCount, 3)
        XCTAssertEqual(storedDocument.metadata.typeCount, 3)
        XCTAssertFalse(storedDocument.metadata.cleanedTextDigest.isEmpty)
        XCTAssertNotNil(
            try NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(
                at: rootURL.appendingPathComponent("corpora").appendingPathComponent(storageFileName)
            )
        )
        XCTAssertEqual(storedDocument.metadata.metadataProfile.sourceLabel, "")
        XCTAssertEqual(storedDocument.text, "alpha beta gamma")
    }

    func testNativeCorpusStoreUpdatesCorpusMetadataAndInfoSummary() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-metadata-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)

        let updated = try store.updateCorpusMetadata(
            corpusId: corpus.id,
            metadata: CorpusMetadataProfile(
                sourceLabel: "教材",
                yearLabel: "2024",
                genreLabel: "教学",
                tags: ["课堂", "基础"]
            )
        )
        let info = try store.loadCorpusInfo(corpusId: corpus.id)

        XCTAssertEqual(updated.metadata.sourceLabel, "教材")
        XCTAssertEqual(updated.metadata.genreLabel, "教学")
        XCTAssertEqual(updated.metadata.tags, ["课堂", "基础"])
        XCTAssertEqual(info.metadata.yearLabel, "2024")
        XCTAssertEqual(info.metadata.tagsText, "课堂, 基础")
    }

    func testNativeCorpusStoreImportsGB18030TextWithoutMojibake() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-gb18030-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("sample-gb18030.txt")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let content = "中文 语料 统计"
        let data = try XCTUnwrap(content.data(using: .wordZGB18030))
        try data.write(to: sourceURL, options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        let opened = try store.openSavedCorpus(corpusId: corpus.id)

        XCTAssertEqual(imported.importedCount, 1)
        XCTAssertEqual(imported.skippedCount, 0)
        XCTAssertEqual(opened.content, content)
    }

    func testNativeCorpusStoreSkipsLikelyBinaryFilesDuringImport() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-binary-skip-\(UUID().uuidString)", isDirectory: true)
        let textURL = rootURL.appendingPathComponent("sample.txt")
        let binaryURL = rootURL.appendingPathComponent("sample.png")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: textURL, atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF, 0xAA, 0x10]).write(to: binaryURL, options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths(
            [textURL.path, binaryURL.path],
            folderId: "",
            preserveHierarchy: false
        )

        XCTAssertEqual(imported.importedCount, 1)
        XCTAssertEqual(imported.skippedCount, 1)
        XCTAssertEqual(try store.listLibrary().corpora.count, 1)
    }

    func testNativeCorpusStoreImportsDOCXAndPDFWithOriginalMetadata() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-rich-import-\(UUID().uuidString)", isDirectory: true)
        let docxURL = rootURL.appendingPathComponent("sample.docx")
        let pdfURL = rootURL.appendingPathComponent("sample.pdf")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try ImportedDocumentTestFixtures.writeDOCX(text: "Hello DOCX", to: docxURL)
        try ImportedDocumentTestFixtures.writePDF(text: "Hello PDF", to: pdfURL)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths(
            [docxURL.path, pdfURL.path],
            folderId: "",
            preserveHierarchy: false
        )

        XCTAssertEqual(imported.importedCount, 2)
        XCTAssertEqual(imported.skippedCount, 0)

        let library = try store.listLibrary()
        XCTAssertEqual(library.corpora.count, 2)

        let docxCorpus = try XCTUnwrap(library.corpora.first(where: { $0.sourceType == "docx" }))
        let pdfCorpus = try XCTUnwrap(library.corpora.first(where: { $0.sourceType == "pdf" }))

        let openedDOCX = try store.openSavedCorpus(corpusId: docxCorpus.id)
        let openedPDF = try store.openSavedCorpus(corpusId: pdfCorpus.id)
        let docxInfo = try store.loadCorpusInfo(corpusId: docxCorpus.id)
        let pdfInfo = try store.loadCorpusInfo(corpusId: pdfCorpus.id)

        XCTAssertEqual(openedDOCX.filePath, docxURL.path)
        XCTAssertEqual(openedPDF.filePath, pdfURL.path)
        XCTAssertEqual(openedDOCX.content.trimmingCharacters(in: .whitespacesAndNewlines), "Hello DOCX")
        XCTAssertEqual(openedPDF.content.trimmingCharacters(in: .whitespacesAndNewlines), "Hello PDF")
        XCTAssertEqual(docxInfo.sourceType, "docx")
        XCTAssertEqual(pdfInfo.sourceType, "pdf")
        XCTAssertEqual(docxInfo.representedPath, docxURL.path)
        XCTAssertEqual(pdfInfo.representedPath, pdfURL.path)
        XCTAssertEqual(docxInfo.detectedEncoding, "")
        XCTAssertEqual(pdfInfo.detectedEncoding, "")
    }

    func testNativeCorpusStoreSkipsUnsupportedFilesInsideImportedDirectory() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-directory-import-\(UUID().uuidString)", isDirectory: true)
        let importDirectory = rootURL.appendingPathComponent("bundle", isDirectory: true)
        let textURL = importDirectory.appendingPathComponent("sample.txt")
        let docxURL = importDirectory.appendingPathComponent("sample.docx")
        let pdfURL = importDirectory.appendingPathComponent("sample.pdf")
        let imageURL = importDirectory.appendingPathComponent("sample.png")
        try FileManager.default.createDirectory(at: importDirectory, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: textURL, atomically: true, encoding: .utf8)
        try ImportedDocumentTestFixtures.writeDOCX(text: "Hello DOCX", to: docxURL)
        try ImportedDocumentTestFixtures.writePDF(text: "Hello PDF", to: pdfURL)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00]).write(to: imageURL, options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths(
            [importDirectory.path],
            folderId: "",
            preserveHierarchy: true
        )

        XCTAssertEqual(imported.importedCount, 3)
        XCTAssertEqual(imported.skippedCount, 1)
        XCTAssertEqual(imported.failureItems.first?.fileName, "sample.png")
        XCTAssertEqual(try store.listLibrary().corpora.count, 3)
    }

    func testNativeCorpusStoreMigratesLegacyTXTStorageToDB() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-migrate-\(UUID().uuidString)", isDirectory: true)
        let corporaDir = rootURL.appendingPathComponent("corpora", isDirectory: true)
        try FileManager.default.createDirectory(at: corporaDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("recycle", isDirectory: true), withIntermediateDirectories: true)
        try "alpha beta".write(
            to: corporaDir.appendingPathComponent("legacy-corpus.txt"),
            atomically: true,
            encoding: .utf8
        )
        try Data("""
        [{
          "id":"corpus-1",
          "name":"Legacy Corpus",
          "folderId":"",
          "folderName":"未分类",
          "sourceType":"txt",
          "representedPath":"/tmp/legacy.txt",
          "storageFileName":"legacy-corpus.txt"
        }]
        """.utf8).write(to: rootURL.appendingPathComponent("corpora.json"), options: .atomic)
        try Data("[]".utf8).write(to: rootURL.appendingPathComponent("folders.json"), options: .atomic)
        try Data("[]".utf8).write(to: rootURL.appendingPathComponent("recycle.json"), options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let opened = try store.openSavedCorpus(corpusId: "corpus-1")
        XCTAssertEqual(opened.displayName, "Legacy Corpus")
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: corporaDir.appendingPathComponent("legacy-corpus.db").path
            )
        )
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: corporaDir.appendingPathComponent("legacy-corpus.txt").path
            )
        )
        let migratedDocument = try XCTUnwrap(
            try NativeCorpusDatabaseSupport.readDocument(at: corporaDir.appendingPathComponent("legacy-corpus.db"))
        )
        XCTAssertEqual(migratedDocument.text, "alpha beta")
        XCTAssertEqual(migratedDocument.metadata.sourceType, "txt")
    }

    func testNativeCorpusStorePersistsExpandedWorkspaceSnapshot() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-workspace-\(UUID().uuidString)", isDirectory: true)
        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        try store.saveWorkspaceSnapshot(WorkspaceStateDraft(
            currentTab: WorkspaceDetailTab.word.snapshotValue,
            currentLibraryFolderId: "folder-1",
            corpusIds: ["corpus-1"],
            corpusNames: ["Demo Corpus"],
            searchQuery: "cloud-1*",
            searchOptions: .default,
            stopwordFilter: .default,
            tokenizeLanguagePreset: .latinFocused,
            tokenizeLemmaStrategy: .lemmaPreferred,
            compareReferenceCorpusID: "corpus-2",
            compareSelectedCorpusIDs: ["corpus-1", "corpus-2"],
            ngramSize: "3",
            ngramPageSize: "100",
            kwicLeftWindow: "4",
            kwicRightWindow: "6",
            collocateLeftWindow: "5",
            collocateRightWindow: "7",
            collocateMinFreq: "2",
            topicsMinTopicSize: "4",
            topicsKeywordDisplayCount: "9",
            topicsIncludeOutliers: false,
            topicsPageSize: "25",
            topicsActiveTopicID: "topic-2",
            chiSquareA: "10",
            chiSquareB: "20",
            chiSquareC: "6",
            chiSquareD: "14",
            chiSquareUseYates: true
        ))

        let snapshot = try store.loadWorkspaceSnapshot()
        XCTAssertEqual(snapshot.currentTab, WorkspaceDetailTab.word.snapshotValue)
        XCTAssertEqual(snapshot.tokenizeLanguagePreset, .latinFocused)
        XCTAssertEqual(snapshot.tokenizeLemmaStrategy, .lemmaPreferred)
        XCTAssertEqual(snapshot.compareReferenceCorpusID, "corpus-2")
        XCTAssertEqual(snapshot.compareSelectedCorpusIDs, ["corpus-1", "corpus-2"])
        XCTAssertEqual(snapshot.topicsMinTopicSize, "4")
        XCTAssertEqual(snapshot.topicsKeywordDisplayCount, "9")
        XCTAssertFalse(snapshot.topicsIncludeOutliers)
        XCTAssertEqual(snapshot.topicsPageSize, "25")
        XCTAssertEqual(snapshot.topicsActiveTopicID, "topic-2")
        XCTAssertEqual(snapshot.chiSquareA, "10")
        XCTAssertEqual(snapshot.chiSquareD, "14")
        XCTAssertTrue(snapshot.chiSquareUseYates)
    }

    func testNativeCorpusStoreLoadsLegacyWorkspaceSnapshotWithDefaultsForNewFields() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-native-legacy-workspace-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let legacyWorkspaceURL = rootURL.appendingPathComponent("workspace-state.json")
        let legacyJSON = """
        {
          "currentTab": "kwic",
          "currentLibraryFolderId": "folder-1",
          "corpusIds": ["corpus-1"],
          "corpusNames": ["Demo Corpus"],
          "searchQuery": "keyword",
          "searchOptions": { "words": true, "caseSensitive": false, "regex": false },
          "stopwordFilter": { "enabled": false, "mode": "exclude", "listText": "" },
          "ngramSize": "2",
          "ngramPageSize": "10",
          "kwicLeftWindow": "3",
          "kwicRightWindow": "4",
          "collocateLeftWindow": "5",
          "collocateRightWindow": "6",
          "collocateMinFreq": "2"
        }
        """
        try legacyJSON.write(to: legacyWorkspaceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let snapshot = try store.loadWorkspaceSnapshot()

        XCTAssertEqual(snapshot.currentTab, "kwic")
        XCTAssertTrue(snapshot.compareSelectedCorpusIDs.isEmpty)
        XCTAssertEqual(snapshot.tokenizeLanguagePreset, .mixedChineseEnglish)
        XCTAssertEqual(snapshot.tokenizeLemmaStrategy, .normalizedSurface)
        XCTAssertEqual(snapshot.topicsMinTopicSize, "2")
        XCTAssertEqual(snapshot.topicsKeywordDisplayCount, "5")
        XCTAssertTrue(snapshot.topicsIncludeOutliers)
        XCTAssertEqual(snapshot.chiSquareA, "")
        XCTAssertFalse(snapshot.chiSquareUseYates)
    }

    func testWorkspaceSnapshotParsesSearchOptionsAndStopwordFilter() {
        let snapshot = WorkspaceSnapshotSummary(json: [
            "search": [
                "query": "alpha",
                "options": [
                    "words": false,
                    "caseSensitive": true,
                    "regex": true
                ],
                "stopwordFilter": [
                    "enabled": true,
                    "mode": "include",
                    "listText": "foo\nbar"
                ]
            ]
        ])

        XCTAssertEqual(snapshot.searchQuery, "alpha")
        XCTAssertEqual(snapshot.searchOptions, SearchOptionsState(words: false, caseSensitive: true, regex: true))
        XCTAssertEqual(snapshot.stopwordFilter.mode, .include)
        XCTAssertEqual(snapshot.stopwordFilter.parsedWords, ["foo", "bar"])
        XCTAssertEqual(snapshot.tokenizeLanguagePreset, .mixedChineseEnglish)
        XCTAssertEqual(snapshot.tokenizeLemmaStrategy, .normalizedSurface)
        XCTAssertTrue(snapshot.compareSelectedCorpusIDs.isEmpty)
        XCTAssertEqual(snapshot.topicsKeywordDisplayCount, "5")
        XCTAssertEqual(snapshot.topicsPageSize, "50")
        XCTAssertEqual(snapshot.chiSquareA, "")
        XCTAssertFalse(snapshot.chiSquareUseYates)
    }

    @MainActor
    func testWorkspaceExportCoordinatorWritesCSVForActiveScene() async throws {
        let dialog = FakeDialogService()
        let exportPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wordz-export.csv")
        try? FileManager.default.removeItem(at: exportPath)
        dialog.savePathResult = exportPath.path
        let coordinator = WorkspaceExportCoordinator(dialogService: dialog)
        let statsScene = StatsSceneBuilder().build(
            from: makeStatsResult(rowCount: 3),
            sortMode: .frequencyDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(StatsColumnKey.allCases)
        )
        let graph = WorkspaceSceneGraph(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: WorkspaceResultSceneNode(
                title: "Stats",
                status: "显示 3 / 3",
                totalRows: 3,
                visibleRows: 3,
                hasResult: true,
                table: statsScene.table,
                tableRows: statsScene.tableRows
            ),
            compare: .empty(title: "Compare", status: ""),
            chiSquare: .empty(title: "Chi-Square", status: ""),
            ngram: .empty(title: "N-Gram", status: ""),
            kwic: .empty(title: "KWIC", status: ""),
            collocate: .empty(title: "Collocate", status: ""),
            locator: .empty(title: "Locator", status: "")
        )

        let savedPath = try await coordinator.exportActiveScene(graph: graph)

        XCTAssertEqual(savedPath, exportPath.path)
        let contents = try String(contentsOf: exportPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("词"))
        XCTAssertTrue(contents.contains("word-0"))
    }

    @MainActor
    func testWorkspaceExportCoordinatorExportsOnlyVisibleStatsColumns() async throws {
        let dialog = FakeDialogService()
        let exportPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wordz-stats-visible-columns.csv")
        try? FileManager.default.removeItem(at: exportPath)
        dialog.savePathResult = exportPath.path
        let coordinator = WorkspaceExportCoordinator(dialogService: dialog)
        let statsScene = StatsSceneBuilder().build(
            from: makeStatsResult(rowCount: 3),
            sortMode: .frequencyDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: [.rank, .word, .normFrequency, .range]
        )
        let graph = WorkspaceSceneGraph(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .stats,
            stats: WorkspaceResultSceneNode(
                title: "Stats",
                status: "显示 3 / 3",
                totalRows: 3,
                visibleRows: 3,
                hasResult: true,
                table: statsScene.table,
                tableRows: statsScene.tableRows
            ),
            compare: .empty(title: "Compare", status: ""),
            chiSquare: .empty(title: "Chi-Square", status: ""),
            ngram: .empty(title: "N-Gram", status: ""),
            kwic: .empty(title: "KWIC", status: ""),
            collocate: .empty(title: "Collocate", status: ""),
            locator: .empty(title: "Locator", status: "")
        )

        _ = try await coordinator.exportActiveScene(graph: graph)

        let lines = try String(contentsOf: exportPath, encoding: .utf8).components(separatedBy: .newlines)
        XCTAssertEqual(lines.first, "\"排名\",\"词\",\"标准频次 /10K\",\"Range (句)\"")
        XCTAssertFalse(lines.first?.contains("\"频次\"") ?? false)
        XCTAssertFalse(lines.first?.contains("\"Norm Range %\"") ?? false)
        XCTAssertTrue(lines.dropFirst().first?.contains("\"1000.00\"") ?? false)
    }

    @MainActor
    func testWorkspaceExportCoordinatorExportsOnlyVisibleWordColumns() async throws {
        let dialog = FakeDialogService()
        let exportPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wordz-word-visible-columns.csv")
        try? FileManager.default.removeItem(at: exportPath)
        dialog.savePathResult = exportPath.path
        let coordinator = WorkspaceExportCoordinator(dialogService: dialog)
        let wordScene = WordSceneBuilder().build(
            from: makeStatsResult(rowCount: 3),
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            sortMode: .frequencyDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: [.word, .normFrequency, .normRange]
        )
        let graph = WorkspaceSceneGraph(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .word,
            word: WorkspaceResultSceneNode(
                title: "Word",
                status: "显示 3 / 3",
                totalRows: 3,
                visibleRows: 3,
                hasResult: true,
                table: wordScene.table,
                tableRows: wordScene.tableRows
            ),
            tokenize: .empty(title: "Tokenize", status: ""),
            stats: .empty(title: "Stats", status: ""),
            compare: .empty(title: "Compare", status: ""),
            chiSquare: .empty(title: "Chi-Square", status: ""),
            ngram: .empty(title: "N-Gram", status: ""),
            kwic: .empty(title: "KWIC", status: ""),
            collocate: .empty(title: "Collocate", status: ""),
            locator: .empty(title: "Locator", status: "")
        )

        _ = try await coordinator.exportActiveScene(graph: graph)

        let lines = try String(contentsOf: exportPath, encoding: .utf8).components(separatedBy: .newlines)
        XCTAssertEqual(lines.first, "\"词\",\"标准频次 /10K\",\"Norm Range % (句)\"")
        XCTAssertFalse(lines.first?.contains("\"频次\"") ?? false)
        XCTAssertFalse(lines.first?.contains("\"Range\"") ?? false)
        XCTAssertTrue(lines.dropFirst().first?.contains("\"100.00\"") ?? false)
    }

    @MainActor
    func testWorkspaceExportCoordinatorExportsSentimentScene() async throws {
        let dialog = FakeDialogService()
        let exportPath = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("wordz-sentiment-visible-columns.csv")
        try? FileManager.default.removeItem(at: exportPath)
        dialog.savePathResult = exportPath.path
        let coordinator = WorkspaceExportCoordinator(dialogService: dialog)
        let sentimentScene = SentimentSceneBuilder().build(
            from: makeSentimentResult(),
            thresholdPreset: .conservative,
            filterQuery: "",
            labelFilter: nil,
            sortMode: .original,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: SentimentPageViewModel.defaultVisibleColumns,
            selectedRowID: nil,
            chartKind: .distributionBar
        )
        let graph = WorkspaceSceneGraph(
            context: .empty,
            sidebar: .empty,
            shell: WorkspaceShellSceneModel(
                workspaceSummary: "工作区：空",
                buildSummary: "SwiftUI + Node.js sidecar",
                toolbar: WorkspaceToolbarSceneModel(items: [])
            ),
            library: .empty,
            settings: .empty,
            activeTab: .sentiment,
            stats: .empty(title: "Stats", status: ""),
            compare: .empty(title: "Compare", status: ""),
            sentiment: WorkspaceResultSceneNode(
                title: "Sentiment",
                status: "显示 2 / 2",
                totalRows: sentimentScene.totalRows,
                visibleRows: sentimentScene.visibleRows,
                hasResult: true,
                table: sentimentScene.table,
                tableRows: sentimentScene.tableRows,
                exportMetadataLines: sentimentScene.exportMetadataLines
            ),
            chiSquare: .empty(title: "Chi-Square", status: ""),
            ngram: .empty(title: "N-Gram", status: ""),
            kwic: .empty(title: "KWIC", status: ""),
            collocate: .empty(title: "Collocate", status: ""),
            locator: .empty(title: "Locator", status: "")
        )

        let savedPath = try await coordinator.exportActiveScene(graph: graph)

        XCTAssertEqual(savedPath, exportPath.path)
        let contents = try String(contentsOf: exportPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("This is good."))
        XCTAssertTrue(contents.contains("This is bad."))
    }

    func testQuickLookPreviewFileServiceWritesTextAndCSVPreviews() throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-quicklook-test-\(UUID().uuidString)", isDirectory: true)
        let service = QuickLookPreviewFileService(rootDirectory: rootURL)
        let textPath = try service.prepare(textDocument: PlainTextExportDocument(
            suggestedName: "tokenized-preview.txt",
            text: "alpha beta\n"
        ))
        let csvPath = try service.prepare(snapshot: NativeTableExportSnapshot(
            suggestedBaseName: "stats-preview",
            table: NativeTableDescriptor(columns: [
                NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil)
            ]),
            rows: [
                NativeTableRowDescriptor(id: "row-1", values: ["word": "alpha", "count": "2"])
            ]
        ))

        XCTAssertTrue(textPath.hasSuffix(".txt"))
        XCTAssertTrue(csvPath.hasSuffix(".csv"))
        XCTAssertEqual(try String(contentsOfFile: textPath, encoding: .utf8), "alpha beta\n")
        XCTAssertTrue(try String(contentsOfFile: csvPath, encoding: .utf8).contains("\"alpha\""))
    }
}
