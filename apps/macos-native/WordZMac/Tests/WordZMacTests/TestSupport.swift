import AppKit
import Foundation
@testable import WordZMac

@MainActor
final class FakeWorkspaceRepository: WorkspaceRepository {
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
    var runChiSquareCallCount = 0
    var runNgramCallCount = 0
    var runWordCloudCallCount = 0
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
    var savedWorkspaceDrafts: [WorkspaceStateDraft] = []
    var savedUISettings: [UISettingsSnapshot] = []

    var bootstrapState: WorkspaceBootstrapState
    var openedCorpus: OpenedCorpus
    var librarySnapshot: LibrarySnapshot
    var recycleSnapshot: RecycleBinSnapshot
    var statsResult: StatsResult
    var corpusInfoResult: CorpusInfoSummary
    var tokenizeResult: TokenizeResult
    var topicsResult: TopicAnalysisResult
    var compareResult: CompareResult
    var chiSquareResult: ChiSquareResult
    var ngramResult: NgramResult
    var wordCloudResult: WordCloudResult
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
    var statsError: Error?
    var tokenizeError: Error?
    var topicsError: Error?
    var compareError: Error?
    var chiSquareError: Error?
    var ngramError: Error?
    var wordCloudError: Error?
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
        chiSquareResult: ChiSquareResult = makeChiSquareResult(),
        ngramResult: NgramResult = makeNgramResult(),
        wordCloudResult: WordCloudResult = makeWordCloudResult(),
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
        self.chiSquareResult = chiSquareResult
        self.ngramResult = ngramResult
        self.wordCloudResult = wordCloudResult
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
            corpora: librarySnapshot.corpora + [nextCorpus]
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
            }
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

    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult {
        runWordCloudCallCount += 1
        if let wordCloudError { throw wordCloudError }
        return wordCloudResult
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
            }
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
            }
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
            corpora: librarySnapshot.corpora.filter { $0.folderId != folderId }
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
final class FakeDialogService: NativeDialogServicing {
    var attachedWindowObjectIdentifier: ObjectIdentifier?
    var importPathsResult: [String]?
    var directoryResult: String?
    var savePathResult: String?
    var exportFormatResult: TableExportFormat? = .csv
    var promptTextResult: String?
    var confirmResult = true

    func attach(window: NSWindow?) {
        attachedWindowObjectIdentifier = window.map(ObjectIdentifier.init)
    }

    func chooseImportPaths() async -> [String]? {
        importPathsResult
    }

    func chooseDirectory(title: String, message: String) async -> String? {
        directoryResult
    }

    func chooseSavePath(title: String, suggestedName: String, allowedExtension: String) async -> String? {
        savePathResult
    }

    func chooseExportFormat() async -> TableExportFormat? {
        exportFormatResult
    }

    func promptText(title: String, message: String, defaultValue: String, confirmTitle: String) async -> String? {
        promptTextResult
    }

    func confirm(title: String, message: String, confirmTitle: String) async -> Bool {
        confirmResult
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
    var openedUserDataDirectoryPath: String?
    var openFeedbackCallCount = 0
    var openReleaseNotesCallCount = 0
    var openProjectHomeCallCount = 0
    var quickLookCallCount = 0
    var lastQuickLookPath: String?
    var shareCallCount = 0
    var lastSharedPaths: [String] = []
    var openDownloadedUpdateCallCount = 0
    var lastOpenedDownloadedUpdatePath: String?
    var revealDownloadedUpdateCallCount = 0
    var lastRevealedDownloadedUpdatePath: String?
    var clearRecentDocumentsCallCount = 0
    var notedRecentDocumentPaths: [String] = []
    var exportedDiagnosticArchivePath: String?
    var exportedSuggestedName: String?
    var exportedPathToReturn: String? = "/tmp/WordZMac-diagnostics.zip"

    func openUserDataDirectory(path: String) async throws {
        openedUserDataDirectoryPath = path
    }

    func openFeedback() async throws {
        openFeedbackCallCount += 1
    }

    func openReleaseNotes() async throws {
        openReleaseNotesCallCount += 1
    }

    func openProjectHome() async throws {
        openProjectHomeCallCount += 1
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
        openDownloadedUpdateCallCount += 1
        lastOpenedDownloadedUpdatePath = path
    }

    func revealDownloadedUpdate(path: String) async throws {
        revealDownloadedUpdateCallCount += 1
        lastRevealedDownloadedUpdatePath = path
    }

    func exportDiagnosticBundle(archivePath: String, suggestedName: String) async throws -> String? {
        exportedDiagnosticArchivePath = archivePath
        exportedSuggestedName = suggestedName
        return exportedPathToReturn
    }

    func clearRecentDocuments() async throws {
        clearRecentDocumentsCallCount += 1
    }

    func noteRecentDocument(path: String) async {
        notedRecentDocumentPaths.append(path)
    }
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

func makeBootstrapState(
    workspaceSnapshot: WorkspaceSnapshotSummary = makeWorkspaceSnapshot(),
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
            ]
        ),
        workspaceSnapshot: workspaceSnapshot,
        uiSettings: uiSettings
    )
}

func makeWorkspaceSnapshot(
    currentTab: String = "kwic",
    corpusNames: [String] = ["Demo Corpus"],
    searchQuery: String = "keyword",
    compareReferenceCorpusID: String = "",
    compareSelectedCorpusIDs: [String] = [],
    frequencyNormalizationUnit: FrequencyNormalizationUnit = FrequencyMetricDefinition.default.normalizationUnit,
    frequencyRangeMode: FrequencyRangeMode = FrequencyMetricDefinition.default.rangeMode,
    ngramSize: String = "2",
    topicsMinTopicSize: String = "2",
    topicsIncludeOutliers: Bool = true,
    topicsPageSize: String = "50",
    topicsActiveTopicID: String = "",
    wordCloudLimit: Int = 80,
    chiSquareA: String = "",
    chiSquareB: String = "",
    chiSquareC: String = "",
    chiSquareD: String = "",
    chiSquareUseYates: Bool = false
) -> WorkspaceSnapshotSummary {
    WorkspaceSnapshotSummary(json: [
        "currentTab": currentTab,
        "currentLibraryFolderId": "folder-1",
        "workspace": ["corpusNames": corpusNames],
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
        "compare": [
            "referenceCorpusID": compareReferenceCorpusID,
            "selectedCorpusIDs": compareSelectedCorpusIDs
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
        "wordCloud": [
            "limit": wordCloudLimit
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
                    TokenizedToken(original: "Alpha", normalized: "alpha", sentenceId: 0, tokenIndex: 0),
                    TokenizedToken(original: "beta", normalized: "beta", sentenceId: 0, tokenIndex: 1),
                    TokenizedToken(original: "gamma", normalized: "gamma", sentenceId: 0, tokenIndex: 2)
                ]
            ),
            TokenizedSentence(
                sentenceId: 1,
                text: "Delta alpha.",
                tokens: [
                    TokenizedToken(original: "Delta", normalized: "delta", sentenceId: 1, tokenIndex: 0),
                    TokenizedToken(original: "alpha", normalized: "alpha", sentenceId: 1, tokenIndex: 1)
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

func makeWordCloudResult(rowCount: Int = 12) -> WordCloudResult {
    let rows: [[Any]] = (0..<rowCount).map { index in
        ["cloud-\(index)", rowCount - index]
    }
    return WordCloudResult(json: ["rows": rows])
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
