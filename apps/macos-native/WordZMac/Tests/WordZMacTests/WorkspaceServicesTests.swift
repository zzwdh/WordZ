import XCTest
@testable import WordZMac

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
            selectedCorpus: selectedCorpus,
            openedCorpus: nil,
            searchQuery: "keyword",
            searchOptions: SearchOptionsState(words: false, caseSensitive: true, regex: true),
            stopwordFilter: StopwordFilterState(enabled: true, mode: .include, listText: "alpha\nbeta"),
            ngramSize: "3",
            ngramPageSize: "100",
            kwicLeftWindow: "3",
            kwicRightWindow: "4",
            collocateLeftWindow: "5",
            collocateRightWindow: "6",
            collocateMinFreq: "2"
        )

        XCTAssertEqual(draft.currentTab, WorkspaceDetailTab.kwic.snapshotValue)
        XCTAssertEqual(draft.currentLibraryFolderId, "folder-1")
        XCTAssertEqual(draft.corpusIds, ["corpus-1"])
        XCTAssertEqual(draft.corpusNames, ["Demo Corpus"])
        XCTAssertEqual(draft.searchQuery, "keyword")
        XCTAssertEqual(draft.searchOptions, SearchOptionsState(words: false, caseSensitive: true, regex: true))
        XCTAssertEqual(draft.stopwordFilter.mode, .include)
        XCTAssertEqual(draft.stopwordFilter.parsedWords, ["alpha", "beta"])
        XCTAssertEqual(draft.ngramSize, "3")
        XCTAssertEqual(draft.ngramPageSize, "100")
        XCTAssertEqual(draft.collocateMinFreq, "2")
    }

    func testWorkspacePresentationBuildsRepresentedPathAndSummary() {
        let appInfo = AppInfoSummary(json: [
            "name": "WordZ",
            "version": "1.0.21",
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
            collocateMinFreq: "2"
        )
        store.applySavedDraft(draft)
        XCTAssertFalse(store.isDocumentEdited)
        XCTAssertEqual(store.workspaceSnapshot?.corpusIds, ["corpus-1"])

        store.resetToEmptyWorkspace()
        XCTAssertEqual(store.workspaceSnapshot?.currentTab, WorkspaceDetailTab.library.snapshotValue)
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
            wordCloud: nil,
            stats: statsScene,
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
            wordCloud: .empty(title: "Word Cloud", status: "尚未生成词云结果"),
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
}
