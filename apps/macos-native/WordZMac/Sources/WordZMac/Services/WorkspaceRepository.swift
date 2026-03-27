import Foundation

struct WorkspaceBootstrapState {
    let appInfo: AppInfoSummary
    let librarySnapshot: LibrarySnapshot
    let workspaceSnapshot: WorkspaceSnapshotSummary
    let uiSettings: UISettingsSnapshot
}

@MainActor
protocol WorkspaceRepository: AnyObject {
    func start(userDataURL: URL?) async throws
    func loadBootstrapState() async throws -> WorkspaceBootstrapState
    func listLibrary(folderId: String) async throws -> LibrarySnapshot
    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult
    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus
    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem
    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem
    func deleteCorpus(corpusId: String) async throws
    func createFolder(name: String) async throws -> LibraryFolderItem
    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem
    func deleteFolder(folderId: String) async throws
    func listRecycleBin() async throws -> RecycleBinSnapshot
    func restoreRecycleEntry(recycleEntryId: String) async throws
    func purgeRecycleEntry(recycleEntryId: String) async throws
    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary
    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary
    func repairLibrary() async throws -> LibraryRepairSummary
    func runStats(text: String) async throws -> StatsResult
    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult
    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult
    func runNgram(text: String, n: Int) async throws -> NgramResult
    func runKWIC(text: String, keyword: String, leftWindow: Int, rightWindow: Int, searchOptions: SearchOptionsState) async throws -> KWICResult
    func runCollocate(text: String, keyword: String, leftWindow: Int, rightWindow: Int, minFreq: Int, searchOptions: SearchOptionsState) async throws -> CollocateResult
    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult
    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult
    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws
    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws
    func stop() async
}

@MainActor
final class EngineWorkspaceRepository: WorkspaceRepository {
    private let engineClient: EngineClient

    init(engineClient: EngineClient = EngineClient()) {
        self.engineClient = engineClient
    }

    func start(userDataURL: URL?) async throws {
        try await engineClient.start(userDataURL: userDataURL)
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        let nextAppInfo = try await engineClient.fetchAppInfo()
        let nextLibrary = try await engineClient.listLibrary()
        let nextWorkspace = try await engineClient.fetchWorkspaceState()
        let nextUISettings = try await engineClient.fetchUISettings()

        return WorkspaceBootstrapState(
            appInfo: nextAppInfo,
            librarySnapshot: nextLibrary,
            workspaceSnapshot: nextWorkspace,
            uiSettings: nextUISettings
        )
    }

    func listLibrary(folderId: String = "all") async throws -> LibrarySnapshot {
        try await engineClient.listLibrary(folderId: folderId)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        try await engineClient.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        try await engineClient.openSavedCorpus(corpusId: corpusId)
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        try await engineClient.renameCorpus(corpusId: corpusId, newName: newName)
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        try await engineClient.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
    }

    func deleteCorpus(corpusId: String) async throws {
        try await engineClient.deleteCorpus(corpusId: corpusId)
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        try await engineClient.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        try await engineClient.renameFolder(folderId: folderId, newName: newName)
    }

    func deleteFolder(folderId: String) async throws {
        try await engineClient.deleteFolder(folderId: folderId)
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        try await engineClient.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        try await engineClient.restoreRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        try await engineClient.purgeRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        try await engineClient.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        try await engineClient.restoreLibrary(sourcePath: sourcePath)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        try await engineClient.repairLibrary()
    }

    func runStats(text: String) async throws -> StatsResult {
        try await engineClient.runStats(text: text)
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        try await engineClient.runCompare(comparisonEntries: comparisonEntries)
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        try await engineClient.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        try await engineClient.runNgram(text: text, n: n)
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        try await engineClient.runKWIC(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        try await engineClient.runCollocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
    }

    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult {
        try await engineClient.runWordCloud(text: text, limit: limit)
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        try await engineClient.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        try await engineClient.saveWorkspaceState(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        try await engineClient.saveUISettings(snapshot)
    }

    func stop() async {
        await engineClient.stop()
    }
}
