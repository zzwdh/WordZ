import AppKit
import Foundation
@testable import WordZMac

@MainActor
final class FakeWorkspaceRepository: WorkspaceRepository, CorpusSetManagingRepository, AnalysisPresetManagingRepository {
    var startedUserDataURL: URL?
    var stopCalled = false
    var loadBootstrapStateCallCount = 0
    var openSavedCorpusCallCount = 0
    var loadCorpusInfoCallCount = 0
    var updateCorpusMetadataCallCount = 0
    var runStatsCallCount = 0
    var runTokenizeCallCount = 0
    var runTopicsCallCount = 0
    var runCompareCallCount = 0
    var runKeywordCallCount = 0
    var runChiSquareCallCount = 0
    var runNgramCallCount = 0
    var runKWICCallCount = 0
    var runCollocateCallCount = 0
    var runLocatorCallCount = 0
    var lastRunKWICSearchOptions = SearchOptionsState.default
    var lastRunCollocateSearchOptions = SearchOptionsState.default
    var lastRunLocatorSentenceId: Int?
    var lastRunLocatorNodeIndex: Int?
    var importCorpusPathsCallCount = 0
    var listLibraryCallCount = 0
    var createFolderCallCount = 0
    var renameCorpusCallCount = 0
    var moveCorpusCallCount = 0
    var deleteCorpusCallCount = 0
    var renameFolderCallCount = 0
    var deleteFolderCallCount = 0
    var listRecycleBinCallCount = 0
    var restoreRecycleEntryCallCount = 0
    var purgeRecycleEntryCallCount = 0
    var backupLibraryCallCount = 0
    var restoreLibraryCallCount = 0
    var repairLibraryCallCount = 0
    var saveCorpusSetCallCount = 0
    var deleteCorpusSetCallCount = 0
    var listAnalysisPresetsCallCount = 0
    var saveAnalysisPresetCallCount = 0
    var deleteAnalysisPresetCallCount = 0
    var savedWorkspaceDrafts: [WorkspaceStateDraft] = []
    var savedUISettings: [UISettingsSnapshot] = []
    var analysisPresetItems: [AnalysisPresetItem] = []

    var bootstrapState: WorkspaceBootstrapState
    var openedCorpus: OpenedCorpus
    var librarySnapshot: LibrarySnapshot
    var recycleSnapshot: RecycleBinSnapshot
    var statsResult: StatsResult
    var corpusInfoResult: CorpusInfoSummary
    var tokenizeResult: TokenizeResult
    var topicsResult: TopicAnalysisResult
    var compareResult: CompareResult
    var keywordResult: KeywordResult
    var chiSquareResult: ChiSquareResult
    var ngramResult: NgramResult
    var kwicResult: KWICResult
    var collocateResult: CollocateResult
    var locatorResult: LocatorResult
    var backupSummary: LibraryBackupSummary
    var restoreSummary: LibraryRestoreSummary
    var repairSummary: LibraryRepairSummary

    var startError: Error?
    var loadError: Error?
    var openError: Error?
    var updateCorpusMetadataError: Error?
    var importError: Error?
    var listLibraryError: Error?
    var createFolderError: Error?
    var renameCorpusError: Error?
    var moveCorpusError: Error?
    var deleteCorpusError: Error?
    var renameFolderError: Error?
    var deleteFolderError: Error?
    var listRecycleError: Error?
    var restoreRecycleError: Error?
    var purgeRecycleError: Error?
    var backupError: Error?
    var restoreError: Error?
    var repairError: Error?
    var saveCorpusSetError: Error?
    var deleteCorpusSetError: Error?
    var listAnalysisPresetsError: Error?
    var saveAnalysisPresetError: Error?
    var deleteAnalysisPresetError: Error?
    var statsError: Error?
    var tokenizeError: Error?
    var topicsError: Error?
    var compareError: Error?
    var keywordError: Error?
    var chiSquareError: Error?
    var ngramError: Error?
    var kwicError: Error?
    var collocateError: Error?
    var locatorError: Error?
    var saveWorkspaceError: Error?
    var saveUISettingsError: Error?
    var topicsDelayNanoseconds: UInt64 = 0

    init(
        bootstrapState: WorkspaceBootstrapState = makeBootstrapState(),
        openedCorpus: OpenedCorpus = makeOpenedCorpus(),
        recycleSnapshot: RecycleBinSnapshot = makeRecycleSnapshot(),
        statsResult: StatsResult = makeStatsResult(),
        corpusInfoResult: CorpusInfoSummary = makeCorpusInfoSummary(),
        tokenizeResult: TokenizeResult = makeTokenizeResult(),
        topicsResult: TopicAnalysisResult = makeTopicAnalysisResult(),
        compareResult: CompareResult = makeCompareResult(),
        keywordResult: KeywordResult = makeKeywordResult(),
        chiSquareResult: ChiSquareResult = makeChiSquareResult(),
        ngramResult: NgramResult = makeNgramResult(),
        kwicResult: KWICResult = makeKWICResult(),
        collocateResult: CollocateResult = makeCollocateResult(),
        locatorResult: LocatorResult = makeLocatorResult(),
        backupSummary: LibraryBackupSummary = makeLibraryBackupSummary(),
        restoreSummary: LibraryRestoreSummary = makeLibraryRestoreSummary(),
        repairSummary: LibraryRepairSummary = makeLibraryRepairSummary()
    ) {
        self.bootstrapState = bootstrapState
        self.openedCorpus = openedCorpus
        self.librarySnapshot = bootstrapState.librarySnapshot
        self.recycleSnapshot = recycleSnapshot
        self.statsResult = statsResult
        self.corpusInfoResult = corpusInfoResult
        self.tokenizeResult = tokenizeResult
        self.topicsResult = topicsResult
        self.compareResult = compareResult
        self.keywordResult = keywordResult
        self.chiSquareResult = chiSquareResult
        self.ngramResult = ngramResult
        self.kwicResult = kwicResult
        self.collocateResult = collocateResult
        self.locatorResult = locatorResult
        self.backupSummary = backupSummary
        self.restoreSummary = restoreSummary
        self.repairSummary = repairSummary
    }

    func start(userDataURL: URL?) async throws {
        startedUserDataURL = userDataURL
        if let startError { throw startError }
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        loadBootstrapStateCallCount += 1
        if let loadError { throw loadError }
        return WorkspaceBootstrapState(
            appInfo: bootstrapState.appInfo,
            librarySnapshot: librarySnapshot,
            workspaceSnapshot: bootstrapState.workspaceSnapshot,
            uiSettings: bootstrapState.uiSettings
        )
    }

    func listLibrary(folderId: String) async throws -> LibrarySnapshot {
        listLibraryCallCount += 1
        if let listLibraryError { throw listLibraryError }
        return librarySnapshot
    }

    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) async throws -> LibraryCorpusSetItem {
        saveCorpusSetCallCount += 1
        if let saveCorpusSetError { throw saveCorpusSetError }

        let corporaByID = Dictionary(uniqueKeysWithValues: librarySnapshot.corpora.map { ($0.id, $0) })
        let resolvedCorpora = corpusIDs.compactMap { corporaByID[$0] }
        let existingSet = librarySnapshot.corpusSets.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        let savedSet = LibraryCorpusSetItem(json: [
            "id": existingSet?.id ?? "set-\(saveCorpusSetCallCount)",
            "name": name,
            "corpusIds": resolvedCorpora.map(\.id),
            "corpusNames": resolvedCorpora.map(\.name),
            "metadataFilter": metadataFilterState.jsonObject,
            "createdAt": existingSet?.createdAt ?? "today",
            "updatedAt": "today"
        ])
        let remainingSets = librarySnapshot.corpusSets.filter { $0.id != savedSet.id }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora,
            corpusSets: remainingSets + [savedSet]
        )
        return savedSet
    }

    func deleteCorpusSet(corpusSetID: String) async throws {
        deleteCorpusSetCallCount += 1
        if let deleteCorpusSetError { throw deleteCorpusSetError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora,
            corpusSets: librarySnapshot.corpusSets.filter { $0.id != corpusSetID }
        )
    }

    func listAnalysisPresets() async throws -> [AnalysisPresetItem] {
        listAnalysisPresetsCallCount += 1
        if let listAnalysisPresetsError { throw listAnalysisPresetsError }
        return analysisPresetItems
    }

    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) async throws -> AnalysisPresetItem {
        saveAnalysisPresetCallCount += 1
        if let saveAnalysisPresetError { throw saveAnalysisPresetError }

        let existing = analysisPresetItems.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let preset = AnalysisPresetItem(
            id: existing?.id ?? "preset-\(saveAnalysisPresetCallCount)",
            name: name,
            createdAt: existing?.createdAt ?? "today",
            updatedAt: "today",
            snapshot: WorkspaceSnapshotSummary(draft: draft)
        )
        analysisPresetItems.removeAll { $0.id == preset.id }
        analysisPresetItems.insert(preset, at: 0)
        return preset
    }

    func deleteAnalysisPreset(presetID: String) async throws {
        deleteAnalysisPresetCallCount += 1
        if let deleteAnalysisPresetError { throw deleteAnalysisPresetError }
        analysisPresetItems.removeAll { $0.id == presetID }
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        importCorpusPathsCallCount += 1
        if let importError { throw importError }
        let nextCorpus = LibraryCorpusItem(json: [
            "id": "imported-\(importCorpusPathsCallCount)",
            "name": URL(fileURLWithPath: paths.first ?? "Imported Corpus").deletingPathExtension().lastPathComponent,
            "folderId": folderId,
            "folderName": librarySnapshot.folders.first(where: { $0.id == folderId })?.name ?? "Imported",
            "sourceType": "txt",
            "representedPath": paths.first ?? ""
        ])
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora + [nextCorpus],
            corpusSets: librarySnapshot.corpusSets
        )
        return LibraryImportResult(json: [
            "importedCount": 1,
            "skippedCount": max(0, paths.count - 1),
            "importedItems": [[
                "id": nextCorpus.id,
                "name": nextCorpus.name,
                "folderId": nextCorpus.folderId,
                "folderName": nextCorpus.folderName,
                "sourceType": nextCorpus.sourceType
            ]]
        ])
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        openSavedCorpusCallCount += 1
        if let openError { throw openError }
        return openedCorpus
    }

    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary {
        loadCorpusInfoCallCount += 1
        if let openError { throw openError }
        return CorpusInfoSummary(json: [
            "corpusId": corpusId,
            "title": corpusInfoResult.title,
            "folderName": corpusInfoResult.folderName,
            "sourceType": corpusInfoResult.sourceType,
            "representedPath": corpusInfoResult.representedPath,
            "detectedEncoding": corpusInfoResult.detectedEncoding,
            "importedAt": corpusInfoResult.importedAt,
            "tokenCount": corpusInfoResult.tokenCount,
            "typeCount": corpusInfoResult.typeCount,
            "sentenceCount": corpusInfoResult.sentenceCount,
            "paragraphCount": corpusInfoResult.paragraphCount,
            "characterCount": corpusInfoResult.characterCount,
            "ttr": corpusInfoResult.ttr,
            "sttr": corpusInfoResult.sttr,
            "metadata": corpusInfoResult.metadata.jsonObject
        ])
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) async throws -> LibraryCorpusItem {
        updateCorpusMetadataCallCount += 1
        if let updateCorpusMetadataError { throw updateCorpusMetadataError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: [
                    "id": corpus.id,
                    "name": corpus.name,
                    "folderId": corpus.folderId,
                    "folderName": corpus.folderName,
                    "sourceType": corpus.sourceType,
                    "representedPath": corpus.representedPath,
                    "metadata": metadata.jsonObject
                ])
            },
            corpusSets: librarySnapshot.corpusSets
        )
        if corpusInfoResult.corpusId == corpusId {
            corpusInfoResult = CorpusInfoSummary(json: [
                "corpusId": corpusInfoResult.corpusId,
                "title": corpusInfoResult.title,
                "folderName": corpusInfoResult.folderName,
                "sourceType": corpusInfoResult.sourceType,
                "representedPath": corpusInfoResult.representedPath,
                "detectedEncoding": corpusInfoResult.detectedEncoding,
                "importedAt": corpusInfoResult.importedAt,
                "tokenCount": corpusInfoResult.tokenCount,
                "typeCount": corpusInfoResult.typeCount,
                "sentenceCount": corpusInfoResult.sentenceCount,
                "paragraphCount": corpusInfoResult.paragraphCount,
                "characterCount": corpusInfoResult.characterCount,
                "ttr": corpusInfoResult.ttr,
                "sttr": corpusInfoResult.sttr,
                "metadata": metadata.jsonObject
            ])
        }
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? librarySnapshot.corpora.first ?? LibraryCorpusItem(json: [:])
    }

    func runStats(text: String) async throws -> StatsResult {
        runStatsCallCount += 1
        if let statsError { throw statsError }
        return statsResult
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        runTokenizeCallCount += 1
        if let tokenizeError { throw tokenizeError }
        return tokenizeResult
    }

    func runTopics(text: String, options: TopicAnalysisOptions) async throws -> TopicAnalysisResult {
        runTopicsCallCount += 1
        if topicsDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: topicsDelayNanoseconds)
        }
        if let topicsError { throw topicsError }
        return topicsResult
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        runCompareCallCount += 1
        if let compareError { throw compareError }
        return compareResult
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult {
        runKeywordCallCount += 1
        if let keywordError { throw keywordError }
        return keywordResult
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        runChiSquareCallCount += 1
        if let chiSquareError { throw chiSquareError }
        return chiSquareResult
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        runNgramCallCount += 1
        if let ngramError { throw ngramError }
        return NgramResult(json: [
            "n": n,
            "rows": ngramResult.rows.map { [$0.phrase, $0.count] }
        ])
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        runKWICCallCount += 1
        lastRunKWICSearchOptions = searchOptions
        if let kwicError { throw kwicError }
        return kwicResult
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        runCollocateCallCount += 1
        lastRunCollocateSearchOptions = searchOptions
        if let collocateError { throw collocateError }
        return collocateResult
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        runLocatorCallCount += 1
        lastRunLocatorSentenceId = sentenceId
        lastRunLocatorNodeIndex = nodeIndex
        if let locatorError { throw locatorError }
        return locatorResult
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        renameCorpusCallCount += 1
        if let renameCorpusError { throw renameCorpusError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: [
                    "id": corpus.id,
                    "name": newName,
                    "folderId": corpus.folderId,
                    "folderName": corpus.folderName,
                    "sourceType": corpus.sourceType
                ])
            },
            corpusSets: librarySnapshot.corpusSets
        )
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? LibraryCorpusItem(json: [:])
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        moveCorpusCallCount += 1
        if let moveCorpusError { throw moveCorpusError }
        let targetName = librarySnapshot.folders.first(where: { $0.id == targetFolderId })?.name ?? "未分类"
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: [
                    "id": corpus.id,
                    "name": corpus.name,
                    "folderId": targetFolderId,
                    "folderName": targetName,
                    "sourceType": corpus.sourceType
                ])
            },
            corpusSets: librarySnapshot.corpusSets
        )
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? LibraryCorpusItem(json: [:])
    }

    func deleteCorpus(corpusId: String) async throws {
        deleteCorpusCallCount += 1
        if let deleteCorpusError { throw deleteCorpusError }
        if let deleted = librarySnapshot.corpora.first(where: { $0.id == corpusId }) {
            recycleSnapshot = RecycleBinSnapshot(
                entries: recycleSnapshot.entries + [RecycleBinEntry(json: [
                    "recycleEntryId": "recycle-\(deleteCorpusCallCount)",
                    "type": "corpus",
                    "deletedAt": "today",
                    "name": deleted.name,
                    "originalFolderName": deleted.folderName,
                    "sourceType": deleted.sourceType,
                    "itemCount": 1
                ])],
                folderCount: recycleSnapshot.folderCount,
                corpusCount: recycleSnapshot.corpusCount + 1,
                totalCount: recycleSnapshot.totalCount + 1
            )
        }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.filter { $0.id != corpusId }
        )
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        createFolderCallCount += 1
        if let createFolderError { throw createFolderError }
        let folder = LibraryFolderItem(json: ["id": "folder-\(createFolderCallCount + 10)", "name": name])
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders + [folder],
            corpora: librarySnapshot.corpora
        )
        return folder
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        renameFolderCallCount += 1
        if let renameFolderError { throw renameFolderError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders.map { folder in
                guard folder.id == folderId else { return folder }
                return LibraryFolderItem(json: ["id": folder.id, "name": newName])
            },
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.folderId == folderId else { return corpus }
                return LibraryCorpusItem(json: [
                    "id": corpus.id,
                    "name": corpus.name,
                    "folderId": folderId,
                    "folderName": newName,
                    "sourceType": corpus.sourceType
                ])
            }
        )
        return librarySnapshot.folders.first(where: { $0.id == folderId }) ?? LibraryFolderItem(json: [:])
    }

    func deleteFolder(folderId: String) async throws {
        deleteFolderCallCount += 1
        if let deleteFolderError { throw deleteFolderError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders.filter { $0.id != folderId },
            corpora: librarySnapshot.corpora.filter { $0.folderId != folderId },
            corpusSets: librarySnapshot.corpusSets
        )
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        listRecycleBinCallCount += 1
        if let listRecycleError { throw listRecycleError }
        return recycleSnapshot
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        restoreRecycleEntryCallCount += 1
        if let restoreRecycleError { throw restoreRecycleError }
        recycleSnapshot = RecycleBinSnapshot(
            entries: recycleSnapshot.entries.filter { $0.recycleEntryId != recycleEntryId },
            folderCount: recycleSnapshot.folderCount,
            corpusCount: max(0, recycleSnapshot.corpusCount - 1),
            totalCount: max(0, recycleSnapshot.totalCount - 1)
        )
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        purgeRecycleEntryCallCount += 1
        if let purgeRecycleError { throw purgeRecycleError }
        recycleSnapshot = RecycleBinSnapshot(
            entries: recycleSnapshot.entries.filter { $0.recycleEntryId != recycleEntryId },
            folderCount: recycleSnapshot.folderCount,
            corpusCount: max(0, recycleSnapshot.corpusCount - 1),
            totalCount: max(0, recycleSnapshot.totalCount - 1)
        )
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        backupLibraryCallCount += 1
        if let backupError { throw backupError }
        return backupSummary
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        restoreLibraryCallCount += 1
        if let restoreError { throw restoreError }
        return restoreSummary
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        repairLibraryCallCount += 1
        if let repairError { throw repairError }
        return repairSummary
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        if let saveWorkspaceError { throw saveWorkspaceError }
        savedWorkspaceDrafts.append(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        if let saveUISettingsError { throw saveUISettingsError }
        savedUISettings.append(snapshot)
    }

    func stop() async {
        stopCalled = true
    }
}

@MainActor
final class FakeLibraryCoordinator: LibraryCoordinating {
    var openedCorpus: OpenedCorpus
    var lastSelectedCorpusID: String?
    var handleSelectionChangeResult = false
    var openSelectionCallCount = 0
    var ensureOpenedCorpusCallCount = 0

    init(openedCorpus: OpenedCorpus = makeOpenedCorpus()) {
        self.openedCorpus = openedCorpus
    }

    func openSelection(selectedCorpusID: String?) async throws -> OpenedCorpus {
        openSelectionCallCount += 1
        lastSelectedCorpusID = selectedCorpusID
        return openedCorpus
    }

    func ensureOpenedCorpus(selectedCorpusID: String?) async throws -> OpenedCorpus {
        ensureOpenedCorpusCallCount += 1
        lastSelectedCorpusID = selectedCorpusID
        return openedCorpus
    }

    func handleSelectionChange(to selectedCorpusID: String?) -> Bool {
        lastSelectedCorpusID = selectedCorpusID
        return handleSelectionChangeResult
    }
}

struct FakeBootstrapApplier: WorkspaceBootstrapApplying {
    func apply(_ bootstrapState: WorkspaceBootstrapState, to features: WorkspaceFeatureSet) {}
    func finalizeRefresh(features: WorkspaceFeatureSet) async {}
}

@MainActor
final class FakeWorkspaceCoordinatorFactory: WorkspaceCoordinatorBuilding {
    let result: WorkspaceCoordinatorSet
    var makeCallCount = 0

    init(result: WorkspaceCoordinatorSet) {
        self.result = result
    }

    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: NativeWindowDocumentController,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        libraryCoordinator: (any LibraryCoordinating)?
    ) -> WorkspaceCoordinatorSet {
        makeCallCount += 1
        return result
    }
}

@MainActor
final class FakeRuntimeDependencyFactory: MainWorkspaceRuntimeDependencyBuilding {
    let result: MainWorkspaceRuntimeDependencies
    var makeCallCount = 0

    init(result: MainWorkspaceRuntimeDependencies) {
        self.result = result
    }

    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: NativeWindowDocumentController,
        dialogService: NativeDialogServicing,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        hostActionService: (any NativeHostActionServicing)?,
        updateService: (any NativeUpdateServicing)?,
        notificationService: (any NativeNotificationServicing)?,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: (any LibraryCoordinating)?,
        coordinatorFactory: (any WorkspaceCoordinatorBuilding)?
    ) -> MainWorkspaceRuntimeDependencies {
        makeCallCount += 1
        return result
    }
}

@MainActor
func makeWorkspaceFlowCoordinator(
    repository: any WorkspaceRepository,
    workspacePersistence: WorkspacePersistenceService = WorkspacePersistenceService(),
    workspacePresentation: WorkspacePresentationService = WorkspacePresentationService(),
    sceneStore: WorkspaceSceneStore = WorkspaceSceneStore(),
    windowDocumentController: NativeWindowDocumentController = NativeWindowDocumentController(),
    dialogService: NativeDialogServicing = NativeSheetDialogService(),
    hostActionService: (any NativeHostActionServicing)? = nil,
    sessionStore: WorkspaceSessionStore,
    hostPreferencesStore: (any NativeHostPreferencesStoring)? = nil,
    libraryCoordinator: any LibraryCoordinating,
    libraryManagementCoordinator: (any LibraryManagementCoordinating)? = nil,
    exportCoordinator: (any WorkspaceExportCoordinating)? = nil,
    taskCenter: NativeTaskCenter? = nil
) -> WorkspaceFlowCoordinator {
    let resolvedHostActionService = hostActionService ?? NativeHostActionService(dialogService: dialogService)
    let resolvedHostPreferencesStore = hostPreferencesStore ?? NativeHostPreferencesStore()
    let resolvedLibraryManagementCoordinator = libraryManagementCoordinator ?? LibraryManagementCoordinator(
        repository: repository,
        dialogService: dialogService,
        sessionStore: sessionStore
    )
    let resolvedExportCoordinator = exportCoordinator ?? WorkspaceExportCoordinator(dialogService: dialogService)
    let resolvedTaskCenter = taskCenter ?? NativeTaskCenter()

    return WorkspaceFlowCoordinator(
        repository: repository,
        workspacePersistence: workspacePersistence,
        workspacePresentation: workspacePresentation,
        sceneStore: sceneStore,
        windowDocumentController: windowDocumentController,
        dialogService: dialogService,
        hostActionService: resolvedHostActionService,
        sessionStore: sessionStore,
        hostPreferencesStore: resolvedHostPreferencesStore,
        libraryCoordinator: libraryCoordinator,
        libraryManagementCoordinator: resolvedLibraryManagementCoordinator,
        exportCoordinator: resolvedExportCoordinator,
        taskCenter: resolvedTaskCenter
    )
}

@MainActor
func makeAppCoordinator(
    repository: any WorkspaceRepository,
    sceneStore: WorkspaceSceneStore,
    sessionStore: WorkspaceSessionStore,
    flowCoordinator: WorkspaceFlowCoordinator,
    hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
    buildMetadataProvider: any NativeBuildMetadataProviding = NativeBuildMetadataService()
) -> AppCoordinator {
    AppCoordinator(
        repository: repository,
        bootstrapApplier: WorkspaceBootstrapApplier(
            sceneStore: sceneStore,
            sessionStore: sessionStore,
            flowCoordinator: flowCoordinator,
            hostPreferencesStore: hostPreferencesStore,
            buildMetadataProvider: buildMetadataProvider
        )
    )
}

@MainActor
func makeMainWorkspaceViewModel(
    repository: any WorkspaceRepository,
    workspacePersistence: WorkspacePersistenceService = WorkspacePersistenceService(),
    workspacePresentation: WorkspacePresentationService = WorkspacePresentationService(),
    sceneStore: WorkspaceSceneStore = WorkspaceSceneStore(),
    sceneGraphStore: WorkspaceSceneGraphStore = WorkspaceSceneGraphStore(),
    rootSceneBuilder: any RootContentSceneBuilding = RootContentSceneBuilder(),
    windowDocumentController: NativeWindowDocumentController = NativeWindowDocumentController(),
    dialogService: NativeDialogServicing = NativeSheetDialogService(),
    hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore(),
    hostActionService: (any NativeHostActionServicing)? = nil,
    quickLookPreviewFileService: any QuickLookPreviewFilePreparing = QuickLookPreviewFileService(),
    reportBundleService: any AnalysisReportBundleServicing = AnalysisReportBundleService(),
    updateService: (any NativeUpdateServicing)? = nil,
    notificationService: (any NativeNotificationServicing)? = nil,
    buildMetadataProvider: any NativeBuildMetadataProviding = NativeBuildMetadataService(),
    diagnosticsBundleService: any NativeDiagnosticsBundleServicing = NativeDiagnosticsBundleService(),
    taskCenter: NativeTaskCenter = NativeTaskCenter(),
    sessionStore: WorkspaceSessionStore = WorkspaceSessionStore(),
    libraryCoordinator: (any LibraryCoordinating)? = nil,
    coordinatorFactory: (any WorkspaceCoordinatorBuilding)? = nil,
    runtimeDependencyFactory: (any MainWorkspaceRuntimeDependencyBuilding)? = nil,
    sidebar: LibrarySidebarViewModel = LibrarySidebarViewModel(),
    shell: WorkspaceShellViewModel = WorkspaceShellViewModel(),
    library: LibraryManagementViewModel = LibraryManagementViewModel(),
    stats: StatsPageViewModel = StatsPageViewModel(),
    word: WordPageViewModel = WordPageViewModel(),
    tokenize: TokenizePageViewModel = TokenizePageViewModel(),
    topics: TopicsPageViewModel = TopicsPageViewModel(),
    compare: ComparePageViewModel = ComparePageViewModel(),
    keyword: KeywordPageViewModel = KeywordPageViewModel(),
    chiSquare: ChiSquarePageViewModel = ChiSquarePageViewModel(),
    ngram: NgramPageViewModel = NgramPageViewModel(),
    kwic: KWICPageViewModel = KWICPageViewModel(),
    collocate: CollocatePageViewModel = CollocatePageViewModel(),
    locator: LocatorPageViewModel = LocatorPageViewModel(),
    settings: WorkspaceSettingsViewModel = WorkspaceSettingsViewModel()
) -> MainWorkspaceViewModel {
    let resolvedRuntimeDependencyFactory = runtimeDependencyFactory ?? MainWorkspaceRuntimeDependencyFactory()
    let runtimeDependencies = resolvedRuntimeDependencyFactory.make(
        repository: repository,
        workspacePersistence: workspacePersistence,
        workspacePresentation: workspacePresentation,
        sceneStore: sceneStore,
        windowDocumentController: windowDocumentController,
        dialogService: dialogService,
        hostPreferencesStore: hostPreferencesStore,
        hostActionService: hostActionService,
        updateService: updateService,
        notificationService: notificationService,
        buildMetadataProvider: buildMetadataProvider,
        taskCenter: taskCenter,
        sessionStore: sessionStore,
        libraryCoordinator: libraryCoordinator,
        coordinatorFactory: coordinatorFactory
    )

    return MainWorkspaceViewModel(
        repository: repository,
        runtimeDependencies: runtimeDependencies,
        sceneStore: sceneStore,
        sceneGraphStore: sceneGraphStore,
        rootSceneBuilder: rootSceneBuilder,
        dialogService: dialogService,
        hostPreferencesStore: hostPreferencesStore,
        quickLookPreviewFileService: quickLookPreviewFileService,
        reportBundleService: reportBundleService,
        buildMetadataProvider: buildMetadataProvider,
        diagnosticsBundleService: diagnosticsBundleService,
        taskCenter: taskCenter,
        sessionStore: sessionStore,
        sidebar: sidebar,
        shell: shell,
        library: library,
        stats: stats,
        word: word,
        tokenize: tokenize,
        topics: topics,
        compare: compare,
        keyword: keyword,
        chiSquare: chiSquare,
        ngram: ngram,
        kwic: kwic,
        collocate: collocate,
        locator: locator,
        settings: settings
    )
}

struct FakeBuildMetadataProvider: NativeBuildMetadataProviding {
    var metadata = NativeBuildMetadata(
        appName: "WordZ",
        bundleIdentifier: "com.test.wordz",
        version: "1.0",
        buildNumber: "1",
        architecture: "arm64",
        builtAt: "2026-04-08",
        gitCommit: "test-commit",
        gitBranch: "test",
        distributionChannel: "test",
        executableSHA256: "sha256"
        ,
        bundlePath: "/Applications/WordZ.app",
        executablePath: "/Applications/WordZ.app/Contents/MacOS/WordZ",
        sourceLabel: "test"
    )

    func current() -> NativeBuildMetadata {
        metadata
    }
}

@MainActor
final class FakeDialogService: NativeDialogServicing {
    var importPathsResult: [String]?
    var directoryResult: String?
    var savePathResult: String?
    var exportFormatResult: TableExportFormat? = .csv
    var promptTextResult: String?
    var confirmResult = true
    var promptTextPreferredRoute: NativeWindowRoute?
    var confirmPreferredRoute: NativeWindowRoute?

    func chooseImportPaths(preferredRoute: NativeWindowRoute?) async -> [String]? {
        return importPathsResult
    }

    func chooseDirectory(title: String, message: String, preferredRoute: NativeWindowRoute?) async -> String? {
        return directoryResult
    }

    func chooseSavePath(
        title: String,
        suggestedName: String,
        allowedExtension: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        return savePathResult
    }

    func chooseExportFormat(preferredRoute: NativeWindowRoute?) async -> TableExportFormat? {
        return exportFormatResult
    }

    func promptText(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        promptTextPreferredRoute = preferredRoute
        return promptTextResult
    }

    func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> Bool {
        confirmPreferredRoute = preferredRoute
        return confirmResult
    }
}

@MainActor
final class InMemoryHostPreferencesStore: NativeHostPreferencesStoring {
    var snapshot = NativeHostPreferencesSnapshot.default
    var saveCallCount = 0
    var recordRecentCallCount = 0
    var clearRecentCallCount = 0
    var recordUpdateCheckCallCount = 0
    var recordDownloadedUpdateCallCount = 0
    var clearDownloadedUpdateCallCount = 0

    func load() -> NativeHostPreferencesSnapshot {
        snapshot
    }

    func save(_ snapshot: NativeHostPreferencesSnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }

    func recordRecentDocument(
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String
    ) throws -> NativeHostPreferencesSnapshot {
        recordRecentCallCount += 1
        snapshot.recentDocuments.removeAll { $0.corpusID == corpusID }
        snapshot.recentDocuments.insert(
            RecentDocumentItem(
                corpusID: corpusID,
                title: title,
                subtitle: subtitle,
                representedPath: representedPath,
                lastOpenedAt: "2026-03-26T00:00:00Z"
            ),
            at: 0
        )
        return snapshot
    }

    func clearRecentDocuments() throws -> NativeHostPreferencesSnapshot {
        clearRecentCallCount += 1
        snapshot.recentDocuments = []
        return snapshot
    }

    func recordUpdateCheck(status: String) throws -> NativeHostPreferencesSnapshot {
        recordUpdateCheckCallCount += 1
        snapshot.lastUpdateCheckAt = "2026-03-26T00:00:00Z"
        snapshot.lastUpdateStatus = status
        return snapshot
    }

    func recordDownloadedUpdate(version: String, name: String, path: String) throws -> NativeHostPreferencesSnapshot {
        recordDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = version
        snapshot.downloadedUpdateName = name
        snapshot.downloadedUpdatePath = path
        return snapshot
    }

    func clearDownloadedUpdate() throws -> NativeHostPreferencesSnapshot {
        clearDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = ""
        snapshot.downloadedUpdateName = ""
        snapshot.downloadedUpdatePath = ""
        return snapshot
    }
}

@MainActor
final class FakeHostActionService: NativeHostActionServicing {
    var openedFilePaths: [String] = []
    var openedExternalURLs: [String] = []
    var quickLookCallCount = 0
    var lastQuickLookPath: String?
    var shareCallCount = 0
    var lastSharedPaths: [String] = []
    var openDownloadedUpdateAndTerminateCallCount = 0
    var lastInstalledDownloadedUpdatePath: String?
    var revealDownloadedUpdateCallCount = 0
    var lastRevealedDownloadedUpdatePath: String?
    var clearRecentDocumentsCallCount = 0
    var exportedArchivePath: String?
    var exportedArchiveTitle: String?
    var exportedArchivePathToReturn: String? = "/tmp/WordZMac-report.zip"
    var exportedArchivePreferredRoute: NativeWindowRoute?
    var exportedDiagnosticArchivePath: String?
    var exportedPathToReturn: String? = "/tmp/WordZMac-diagnostics.zip"
    var exportedDiagnosticPreferredRoute: NativeWindowRoute?

    func openUserDataDirectory(path: String) async throws {
    }

    func openFile(path: String) async throws {
        openedFilePaths.append(path)
    }

    func openURL(_ value: String) async throws {
        openedExternalURLs.append(value)
    }

    func openFeedback() async throws {
    }

    func openReleaseNotes() async throws {
    }

    func openProjectHome() async throws {
    }

    func quickLook(path: String) async throws {
        quickLookCallCount += 1
        lastQuickLookPath = path
    }

    func share(paths: [String]) async throws {
        shareCallCount += 1
        lastSharedPaths = paths
    }

    func openDownloadedUpdate(path: String) async throws {
    }

    func openDownloadedUpdateAndTerminate(path: String) async throws {
        openDownloadedUpdateAndTerminateCallCount += 1
        lastInstalledDownloadedUpdatePath = path
    }

    func revealDownloadedUpdate(path: String) async throws {
        revealDownloadedUpdateCallCount += 1
        lastRevealedDownloadedUpdatePath = path
    }

    func exportArchiveBundle(
        archivePath: String,
        suggestedName: String,
        title: String,
        preferredRoute: NativeWindowRoute?
    ) async throws -> String? {
        exportedArchivePath = archivePath
        exportedArchiveTitle = title
        exportedArchivePreferredRoute = preferredRoute
        return exportedArchivePathToReturn
    }

    func exportDiagnosticBundle(
        archivePath: String,
        suggestedName: String,
        preferredRoute: NativeWindowRoute?
    ) async throws -> String? {
        exportedDiagnosticArchivePath = archivePath
        exportedDiagnosticPreferredRoute = preferredRoute
        return exportedPathToReturn
    }

    func clearRecentDocuments() async throws {
        clearRecentDocumentsCallCount += 1
    }

    func noteRecentDocument(path: String) async {}
}

final class FakeDiagnosticsBundleService: NativeDiagnosticsBundleServicing {
    var artifactToReturn = NativeDiagnosticsBundleArtifact(
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics.zip"),
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics")
    )
    private(set) var lastPayload: NativeDiagnosticsBundlePayload?
    private(set) var cleanedArtifacts: [NativeDiagnosticsBundleArtifact] = []

    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeAnalysisReportBundleService: AnalysisReportBundleServicing {
    var artifactToReturn = AnalysisReportBundleArtifact(
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report"),
        bundleDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report/WordZMac-stats-report"),
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-report.zip")
    )
    private(set) var lastPayload: AnalysisReportBundlePayload?
    private(set) var cleanedArtifacts: [AnalysisReportBundleArtifact] = []

    func buildBundle(payload: AnalysisReportBundlePayload) throws -> AnalysisReportBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: AnalysisReportBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeUpdateService: NativeUpdateServicing {
    var checkCallCount = 0
    var downloadCallCount = 0
    var checkDelayNanoseconds: UInt64 = 0
    var downloadDelayNanoseconds: UInt64 = 0
    var result = NativeUpdateCheckResult(
        currentVersion: "1.1.0",
        latestVersion: "1.1.1",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
        statusMessage: "发现新版本 1.1.1，可前往发布页下载安装。",
        updateAvailable: true,
        asset: NativeUpdateAsset(
            name: "WordZ-1.1.1-mac-arm64.dmg",
            downloadURL: "https://example.com/WordZ-1.1.1-mac-arm64.dmg"
        ),
        releaseTitle: "WordZ 1.1.1",
        publishedAt: "2026-03-26T00:00:00Z",
        releaseNotes: ["Native table layout persistence"]
    )
    var downloadResult = NativeDownloadedUpdate(
        version: "1.1.1",
        assetName: "WordZ-1.1.1-mac-arm64.dmg",
        localPath: "/tmp/WordZ-1.1.1-mac-arm64.dmg",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1"
    )
    var error: Error?
    var downloadError: Error?

    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult {
        checkCallCount += 1
        if checkDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: checkDelayNanoseconds)
        }
        if let error { throw error }
        return NativeUpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: result.latestVersion,
            releaseURL: result.releaseURL,
            statusMessage: result.statusMessage,
            updateAvailable: result.updateAvailable,
            asset: result.asset,
            releaseTitle: result.releaseTitle,
            publishedAt: result.publishedAt,
            releaseNotes: result.releaseNotes
        )
    }

    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate {
        downloadCallCount += 1
        if downloadDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: downloadDelayNanoseconds)
        }
        if let downloadError { throw downloadError }
        onProgress(0.5)
        onProgress(1)
        return downloadResult
    }
}

@MainActor
final class FakeNotificationService: NativeNotificationServicing {
    private(set) var notifications: [(String, String, String)] = []

    func notify(title: String, subtitle: String, body: String) async {
        notifications.append((title, subtitle, body))
    }
}

@MainActor
final class CountingRootContentSceneBuilder: RootContentSceneBuilding {
    private(set) var buildCallCount = 0

    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel {
        buildCallCount += 1
        return RootContentSceneBuilder().build(
            windowTitle: windowTitle,
            activeTab: activeTab,
            languageMode: languageMode
        )
    }
}

func makeBootstrapState(
    workspaceSnapshot: WorkspaceSnapshotSummary = makeWorkspaceSnapshot(),
    corpusSets: [LibraryCorpusSetItem] = [],
    uiSettings: UISettingsSnapshot = .default
) -> WorkspaceBootstrapState {
    WorkspaceBootstrapState(
        appInfo: AppInfoSummary(json: [
            "name": "WordZ",
            "version": "1.1.0",
            "help": ["Docs", "Feedback"],
            "releaseNotes": [],
            "userDataDir": "/tmp/wordz"
        ]),
        librarySnapshot: LibrarySnapshot(
            folders: [
                LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])
            ],
            corpora: [
                LibraryCorpusItem(json: [
                    "id": "corpus-1",
                    "name": "Demo Corpus",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "representedPath": "/tmp/demo.txt",
                    "metadata": [
                        "sourceLabel": "教材",
                        "yearLabel": "2024",
                        "genreLabel": "教学",
                        "tags": ["课堂", "基础"]
                    ]
                ]),
                LibraryCorpusItem(json: [
                    "id": "corpus-2",
                    "name": "Compare Corpus",
                    "folderId": "folder-1",
                    "folderName": "Default",
                    "sourceType": "txt",
                    "representedPath": "/tmp/compare.txt",
                    "metadata": [
                        "sourceLabel": "期刊",
                        "yearLabel": "2023",
                        "genreLabel": "学术",
                        "tags": ["研究", "对比"]
                    ]
                ])
            ],
            corpusSets: corpusSets
        ),
        workspaceSnapshot: workspaceSnapshot,
        uiSettings: uiSettings
    )
}

func makeWorkspaceSnapshot(
    currentTab: String = "kwic",
    selectedCorpusSetID: String = "",
    corpusNames: [String] = ["Demo Corpus"],
    searchQuery: String = "keyword",
    tokenizeLanguagePreset: TokenizeLanguagePreset = .mixedChineseEnglish,
    tokenizeLemmaStrategy: TokenLemmaStrategy = .normalizedSurface,
    compareReferenceCorpusID: String = "",
    compareSelectedCorpusIDs: [String] = [],
    keywordTargetCorpusID: String = "",
    keywordReferenceCorpusID: String = "",
    keywordLowercased: Bool = true,
    keywordRemovePunctuation: Bool = true,
    keywordMinimumFrequency: String = "2",
    keywordStatistic: KeywordStatisticMethod = .logLikelihood,
    keywordStopwordFilter: StopwordFilterState = .default,
    frequencyNormalizationUnit: FrequencyNormalizationUnit = FrequencyMetricDefinition.default.normalizationUnit,
    frequencyRangeMode: FrequencyRangeMode = FrequencyMetricDefinition.default.rangeMode,
    ngramSize: String = "2",
    topicsMinTopicSize: String = "2",
    topicsIncludeOutliers: Bool = true,
    topicsPageSize: String = "50",
    topicsActiveTopicID: String = "",
    chiSquareA: String = "",
    chiSquareB: String = "",
    chiSquareC: String = "",
    chiSquareD: String = "",
    chiSquareUseYates: Bool = false
) -> WorkspaceSnapshotSummary {
    WorkspaceSnapshotSummary(json: [
        "currentTab": currentTab,
        "currentLibraryFolderId": "folder-1",
        "workspace": [
            "selectedCorpusSetID": selectedCorpusSetID,
            "corpusNames": corpusNames
        ],
        "search": [
            "query": searchQuery,
            "options": [
                "words": true,
                "caseSensitive": false,
                "regex": false
            ],
            "stopwordFilter": [
                "enabled": false,
                "mode": "exclude",
                "listText": StopwordFilterState.defaultListText
            ]
        ],
        "tokenize": [
            "languagePreset": tokenizeLanguagePreset.rawValue,
            "lemmaStrategy": tokenizeLemmaStrategy.rawValue
        ],
        "compare": [
            "referenceCorpusID": compareReferenceCorpusID,
            "selectedCorpusIDs": compareSelectedCorpusIDs
        ],
        "keyword": [
            "targetCorpusID": keywordTargetCorpusID,
            "referenceCorpusID": keywordReferenceCorpusID,
            "lowercased": keywordLowercased,
            "removePunctuation": keywordRemovePunctuation,
            "minimumFrequency": keywordMinimumFrequency,
            "statistic": keywordStatistic.rawValue,
            "stopwordFilter": keywordStopwordFilter.asJSONObject()
        ],
        "frequencyMetrics": [
            "normalizationUnit": frequencyNormalizationUnit.rawValue,
            "rangeMode": frequencyRangeMode.rawValue
        ],
        "ngram": ["pageSize": "10", "size": ngramSize],
        "kwic": ["leftWindow": "3", "rightWindow": "4"],
        "collocate": ["leftWindow": "5", "rightWindow": "6", "minFreq": "2"],
        "topics": [
            "minTopicSize": topicsMinTopicSize,
            "includeOutliers": topicsIncludeOutliers,
            "pageSize": topicsPageSize,
            "activeTopicID": topicsActiveTopicID
        ],
        "chiSquare": [
            "a": chiSquareA,
            "b": chiSquareB,
            "c": chiSquareC,
            "d": chiSquareD,
            "useYates": chiSquareUseYates
        ]
    ])
}

func makeOpenedCorpus(displayName: String = "Demo Corpus") -> OpenedCorpus {
    OpenedCorpus(json: [
        "mode": "saved",
        "filePath": "/tmp/demo.txt",
        "displayName": displayName,
        "content": "alpha beta gamma alpha beta",
        "sourceType": "txt"
    ])
}

func makeCorpusInfoSummary(title: String = "Demo Corpus") -> CorpusInfoSummary {
    CorpusInfoSummary(json: [
        "corpusId": "corpus-1",
        "title": title,
        "folderName": "Default",
        "sourceType": "txt",
        "representedPath": "/tmp/demo.txt",
        "detectedEncoding": "UTF-8",
        "importedAt": "2026-04-03T00:00:00Z",
        "tokenCount": 30,
        "typeCount": 12,
        "sentenceCount": 6,
        "paragraphCount": 3,
        "characterCount": 180,
        "ttr": 0.4,
        "sttr": 0.37,
        "metadata": [
            "sourceLabel": "教材",
            "yearLabel": "2024",
            "genreLabel": "教学",
            "tags": ["课堂", "基础"]
        ]
    ])
}

func makeStatsResult(rowCount: Int = 3) -> StatsResult {
    let tokenCount = rowCount * 10
    let segmentCount = max(rowCount, 1)
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        let count = rowCount - index
        let range = max(1, rowCount - index)
        return [
            "word": "word-\(index)",
            "count": count,
            "rank": index + 1,
            "normFreq": (Double(count) / Double(max(tokenCount, 1))) * 10_000,
            "range": range,
            "normRange": (Double(range) / Double(segmentCount)) * 100,
            "sentenceRange": range,
            "paragraphRange": range
        ]
    }
    return StatsResult(json: [
        "tokenCount": tokenCount,
        "typeCount": rowCount,
        "ttr": 0.5,
        "sttr": 0.4,
        "sentenceCount": segmentCount,
        "paragraphCount": segmentCount,
        "freqRows": rows
    ])
}

func makeTokenizeResult() -> TokenizeResult {
    TokenizeResult(
        sentences: [
            TokenizedSentence(
                sentenceId: 0,
                text: "Alpha beta gamma.",
                tokens: [
                    TokenizedToken(
                        original: "Alpha",
                        normalized: "alpha",
                        sentenceId: 0,
                        tokenIndex: 0,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "alpha", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "beta",
                        normalized: "beta",
                        sentenceId: 0,
                        tokenIndex: 1,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "beta", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "gamma",
                        normalized: "gamma",
                        sentenceId: 0,
                        tokenIndex: 2,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "gamma", lexicalClass: .noun)
                    )
                ]
            ),
            TokenizedSentence(
                sentenceId: 1,
                text: "Delta alpha.",
                tokens: [
                    TokenizedToken(
                        original: "Delta",
                        normalized: "delta",
                        sentenceId: 1,
                        tokenIndex: 0,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "delta", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "alpha",
                        normalized: "alpha",
                        sentenceId: 1,
                        tokenIndex: 1,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "alpha", lexicalClass: .noun)
                    )
                ]
            )
        ]
    )
}

func makeTopicAnalysisResult() -> TopicAnalysisResult {
    TopicAnalysisResult(
        modelVersion: "wordz-topics-english-1",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: "topic-1",
                index: 1,
                isOutlier: false,
                size: 2,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "security", score: 1.42),
                    TopicKeywordCandidate(term: "hacker", score: 1.17)
                ],
                representativeSegmentIDs: ["paragraph-1"]
            ),
            TopicClusterSummary(
                id: TopicAnalysisResult.outlierTopicID,
                index: 0,
                isOutlier: true,
                size: 1,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "misc", score: 0.75)
                ],
                representativeSegmentIDs: ["paragraph-3"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "paragraph-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: "Security researchers discussed hacker communities and disclosure norms.",
                similarityScore: 0.91,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-2",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: "Hackers shared exploit mitigation strategies and coordinated fixes.",
                similarityScore: 0.88,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-3",
                topicID: TopicAnalysisResult.outlierTopicID,
                paragraphIndex: 3,
                text: "A short unrelated paragraph about coffee and weather.",
                similarityScore: 0.0,
                isOutlier: true
            )
        ],
        totalSegments: 3,
        clusteredSegments: 2,
        outlierCount: 1,
        warnings: []
    )
}

func makeNgramResult(rowCount: Int = 3, n: Int = 2) -> NgramResult {
    let rows: [[Any]] = (0..<rowCount).map { index in
        ["phrase-\(index)", rowCount - index]
    }
    return NgramResult(json: [
        "n": n,
        "rows": rows
    ])
}

func makeKWICResult(rowCount: Int = 3) -> KWICResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        [
            "sentenceId": rowCount - index,
            "sentenceTokenIndex": index,
            "left": "left-\(index)",
            "node": "node-\(index)",
            "right": "right-\(index)"
        ]
    }
    return KWICResult(json: ["rows": rows])
}

func makeCollocateResult(rowCount: Int = 3) -> CollocateResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        let row: [String: Any] = [
            "word": "collocate-\(index)",
            "total": rowCount - index,
            "left": index,
            "right": rowCount - index,
            "wordFreq": 10 + index,
            "keywordFreq": 20,
            "rate": Double(rowCount - index) / 10.0,
            "logDice": 8.0 + Double(rowCount - index),
            "mutualInformation": 2.0 + Double(index) / 10.0,
            "tScore": 4.0 + Double(rowCount - index) / 10.0
        ]
        return row
    }
    return CollocateResult(items: rows)
}

func makeCompareResult() -> CompareResult {
    CompareResult(json: [
        "corpora": [
            [
                "corpusId": "corpus-1",
                "corpusName": "Demo Corpus",
                "folderName": "Default",
                "tokenCount": 100,
                "typeCount": 50,
                "ttr": 0.5,
                "sttr": 0.45,
                "topWord": "alpha",
                "topWordCount": 10
            ],
            [
                "corpusId": "corpus-2",
                "corpusName": "Compare Corpus",
                "folderName": "Default",
                "tokenCount": 120,
                "typeCount": 60,
                "ttr": 0.5,
                "sttr": 0.43,
                "topWord": "beta",
                "topWordCount": 12
            ]
        ],
        "rows": [
            [
                "word": "alpha",
                "total": 18,
                "spread": 2,
                "range": 3.2,
                "dominantCorpusName": "Demo Corpus",
                "keyness": 4.21,
                "effectSize": 0.58,
                "pValue": 0.04,
                "referenceNormFreq": 666.7,
                "perCorpus": [
                    ["corpusId": "corpus-1", "corpusName": "Demo Corpus", "folderName": "Default", "count": 10, "tokenCount": 100, "normFreq": 1000.0],
                    ["corpusId": "corpus-2", "corpusName": "Compare Corpus", "folderName": "Default", "count": 8, "tokenCount": 120, "normFreq": 666.7]
                ]
            ],
            [
                "word": "beta",
                "total": 14,
                "spread": 2,
                "range": 2.1,
                "dominantCorpusName": "Compare Corpus",
                "keyness": 3.11,
                "effectSize": 0.44,
                "pValue": 0.08,
                "referenceNormFreq": 500.0,
                "perCorpus": [
                    ["corpusId": "corpus-1", "corpusName": "Demo Corpus", "folderName": "Default", "count": 5, "tokenCount": 100, "normFreq": 500.0],
                    ["corpusId": "corpus-2", "corpusName": "Compare Corpus", "folderName": "Default", "count": 9, "tokenCount": 120, "normFreq": 750.0]
                ]
            ]
        ]
    ])
}

func makeKeywordResult() -> KeywordResult {
    KeywordResult(json: [
        "statistic": KeywordStatisticMethod.logLikelihood.rawValue,
        "targetCorpus": [
            "corpusId": "corpus-1",
            "corpusName": "Target Corpus",
            "folderName": "Default",
            "tokenCount": 120,
            "typeCount": 45
        ],
        "referenceCorpus": [
            "corpusId": "corpus-2",
            "corpusName": "Reference Corpus",
            "folderName": "Default",
            "tokenCount": 200,
            "typeCount": 60
        ],
        "rows": [
            [
                "word": "alpha",
                "rank": 1,
                "targetFrequency": 12,
                "referenceFrequency": 2,
                "targetNormalizedFrequency": 100_000.0,
                "referenceNormalizedFrequency": 10_000.0,
                "keynessScore": 18.42,
                "logRatio": 3.1,
                "pValue": 0.0001
            ],
            [
                "word": "beta",
                "rank": 2,
                "targetFrequency": 8,
                "referenceFrequency": 1,
                "targetNormalizedFrequency": 66_666.67,
                "referenceNormalizedFrequency": 5_000.0,
                "keynessScore": 11.08,
                "logRatio": 2.7,
                "pValue": 0.0009
            ]
        ]
    ])
}

func makeChiSquareResult() -> ChiSquareResult {
    ChiSquareResult(json: [
        "observed": [[12, 30], [6, 40]],
        "expected": [[8.6, 33.4], [9.4, 36.6]],
        "rowTotals": [42, 46],
        "colTotals": [18, 70],
        "total": 88,
        "chiSquare": 2.7412,
        "degreesOfFreedom": 1,
        "pValue": 0.0978,
        "significantAt05": false,
        "significantAt01": false,
        "phi": 0.1765,
        "oddsRatio": 2.6667,
        "yatesCorrection": false,
        "warnings": []
    ])
}

func makeLocatorResult(rowCount: Int = 4) -> LocatorResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        [
            "sentenceId": index,
            "text": "sentence-\(index)",
            "leftWords": index == 1 ? "left target" : "",
            "nodeWord": index == 1 ? "node" : "",
            "rightWords": index == 1 ? "right target" : "",
            "status": index == 1 ? "当前定位" : ""
        ]
    }
    return LocatorResult(json: [
        "sentences": rows,
        "rows": rows
    ])
}

func makeRecycleSnapshot() -> RecycleBinSnapshot {
    RecycleBinSnapshot(json: [
        "entries": [[
            "recycleEntryId": "recycle-1",
            "type": "corpus",
            "deletedAt": "today",
            "name": "Deleted Corpus",
            "originalFolderName": "Default",
            "sourceType": "txt",
            "itemCount": 1
        ]],
        "folderCount": 0,
        "corpusCount": 1,
        "totalCount": 1
    ])
}

func makeLibraryBackupSummary() -> LibraryBackupSummary {
    LibraryBackupSummary(json: [
        "backupDir": "/tmp/wordz-backup",
        "folderCount": 1,
        "corpusCount": 2
    ])
}

func makeLibraryRestoreSummary() -> LibraryRestoreSummary {
    LibraryRestoreSummary(json: [
        "restoredFromDir": "/tmp/wordz-backup",
        "previousLibraryBackupDir": "/tmp/wordz-prev",
        "folderCount": 1,
        "corpusCount": 2
    ])
}

func makeLibraryRepairSummary() -> LibraryRepairSummary {
    LibraryRepairSummary(json: [
        "summary": [
            "repairedManifest": true,
            "repairedFolders": 1,
            "repairedCorpora": 1,
            "recoveredCorpusMeta": 0,
            "quarantinedFolders": 0,
            "quarantinedCorpora": 0,
            "checkedFolders": 1,
            "checkedCorpora": 2
        ],
        "quarantineDir": "/tmp/wordz-quarantine"
    ])
}
