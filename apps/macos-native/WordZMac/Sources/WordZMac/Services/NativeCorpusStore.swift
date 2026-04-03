import Foundation

final class NativeCorpusStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var isInitialized = false
    private var cachedFolders: [NativeFolderRecord]?
    private var cachedCorpora: [NativeCorpusRecord]?
    private var cachedRecycleEntries: [NativeRecycleRecord]?
    private var cachedWorkspaceSnapshot: NativePersistedWorkspaceSnapshot?
    private var cachedUISettings: NativePersistedUISettings?

    private var corporaDirectoryURL: URL { rootURL.appendingPathComponent("corpora", isDirectory: true) }
    private var recycleDirectoryURL: URL { rootURL.appendingPathComponent("recycle", isDirectory: true) }
    private var foldersURL: URL { rootURL.appendingPathComponent("folders.json") }
    private var corporaURL: URL { rootURL.appendingPathComponent("corpora.json") }
    private var recycleURL: URL { rootURL.appendingPathComponent("recycle.json") }
    private var workspaceURL: URL { rootURL.appendingPathComponent("workspace-state.json") }
    private var uiSettingsURL: URL { rootURL.appendingPathComponent("ui-settings.json") }

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func ensureInitialized() throws {
        guard !isInitialized else { return }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corporaDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: recycleDirectoryURL, withIntermediateDirectories: true)

        if !fileManager.fileExists(atPath: foldersURL.path) {
            try saveFolders([])
        }
        if !fileManager.fileExists(atPath: corporaURL.path) {
            try saveCorpora([])
        }
        if !fileManager.fileExists(atPath: recycleURL.path) {
            try saveRecycleEntries([])
        }
        if !fileManager.fileExists(atPath: workspaceURL.path) {
            try saveWorkspaceSnapshot(.empty)
        }
        if !fileManager.fileExists(atPath: uiSettingsURL.path) {
            try saveUISettings(.default)
        }

        _ = try loadFolders()
        _ = try loadCorpora()
        _ = try loadRecycleEntries()
        _ = try loadWorkspacePersistedSnapshot()
        _ = try loadPersistedUISettings()
        isInitialized = true
    }

    func appInfo() -> AppInfoSummary {
        let bundleVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return AppInfoSummary(json: [
            "name": "WordZ",
            "version": bundleVersion ?? "native-preview",
            "help": [
                "原生版当前默认使用 Swift 本地引擎。",
                "导入文本语料后，可直接运行 Stats / Word / KWIC / Collocate / N-Gram / Compare / Locator。"
            ],
            "releaseNotes": [
                "分析可信度升级：Compare 支持固定参考语料与 keyness/log ratio 结果恢复，导出自动写入更多分析元信息。",
                "大语料性能专项推进：结果缓存、后台 scene build、SQLite 语料信息直读和更稳的大表渲染继续增强。",
                "语料库体系升级：本地 `.db` 存储补齐语料元数据编辑、语料信息面板和后续扩展所需的结构化基础。",
                "学术型阅读体验增强：KWIC / Locator 增加特化阅读与引文操作，Collocate 新增 LogDice / MI / T-Score。",
                "发布与诊断工程加强：release manifest/checklist/smoke 更稳，诊断包默认进行本地路径脱敏。"
            ],
            "userDataDir": rootURL.path
        ])
    }

    func listLibrary(folderId: String = "all") throws -> LibrarySnapshot {
        let folders = try loadFolders()
        let corpora = try loadCorpora()
        let filtered = folderId == "all" || folderId.isEmpty
            ? corpora
            : corpora.filter { $0.folderId == folderId }
        return LibrarySnapshot(
            folders: folders.map(\.libraryItem),
            corpora: filtered.map(\.libraryItem)
        )
    }

    func listRecycleBin() throws -> RecycleBinSnapshot {
        let entries = try loadRecycleEntries()
        let entryItems = entries.map(\.recycleItem)
        let folderCount = entries.filter { $0.folder != nil }.count
        let corpusCount = entries.reduce(0) { $0 + $1.corpora.count }
        return RecycleBinSnapshot(
            entries: entryItems,
            folderCount: folderCount,
            corpusCount: corpusCount,
            totalCount: entryItems.count
        )
    }

    func loadWorkspaceSnapshot() throws -> WorkspaceSnapshotSummary {
        try loadWorkspacePersistedSnapshot().workspaceSnapshot
    }

    func saveWorkspaceSnapshot(_ draft: WorkspaceStateDraft) throws {
        let persisted = NativePersistedWorkspaceSnapshot(
            currentTab: draft.currentTab,
            currentLibraryFolderId: draft.currentLibraryFolderId,
            corpusIds: draft.corpusIds,
            corpusNames: draft.corpusNames,
            searchQuery: draft.searchQuery,
            searchOptions: draft.searchOptions,
            stopwordFilter: draft.stopwordFilter,
            compareReferenceCorpusID: draft.compareReferenceCorpusID,
            compareSelectedCorpusIDs: draft.compareSelectedCorpusIDs,
            ngramSize: draft.ngramSize,
            ngramPageSize: draft.ngramPageSize,
            kwicLeftWindow: draft.kwicLeftWindow,
            kwicRightWindow: draft.kwicRightWindow,
            collocateLeftWindow: draft.collocateLeftWindow,
            collocateRightWindow: draft.collocateRightWindow,
            collocateMinFreq: draft.collocateMinFreq,
            topicsMinTopicSize: draft.topicsMinTopicSize,
            topicsIncludeOutliers: draft.topicsIncludeOutliers,
            topicsPageSize: draft.topicsPageSize,
            topicsActiveTopicID: draft.topicsActiveTopicID,
            wordCloudLimit: draft.wordCloudLimit,
            frequencyNormalizationUnit: draft.frequencyNormalizationUnit,
            frequencyRangeMode: draft.frequencyRangeMode,
            chiSquareA: draft.chiSquareA,
            chiSquareB: draft.chiSquareB,
            chiSquareC: draft.chiSquareC,
            chiSquareD: draft.chiSquareD,
            chiSquareUseYates: draft.chiSquareUseYates
        )
        cachedWorkspaceSnapshot = persisted
        try write(persisted, to: workspaceURL)
    }

    func loadUISettings() throws -> UISettingsSnapshot {
        try loadPersistedUISettings().uiSettings
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) throws {
        let persisted = NativePersistedUISettings(
            showWelcomeScreen: snapshot.showWelcomeScreen,
            restoreWorkspace: snapshot.restoreWorkspace,
            debugLogging: snapshot.debugLogging
        )
        cachedUISettings = persisted
        try write(persisted, to: uiSettingsURL)
    }

    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus {
        let corpora = try loadCorpora()
        guard let record = corpora.first(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "语料文件已丢失：\(record.name)"]
            )
        }
        let content = try readStoredCorpusText(at: storageURL, record: record)
        return OpenedCorpus(json: [
            "mode": "saved",
            "filePath": record.representedPath.isEmpty ? storageURL.path : record.representedPath,
            "displayName": record.name,
            "content": content,
            "sourceType": record.sourceType
        ])
    }

    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary {
        let corpora = try loadCorpora()
        guard let record = corpora.first(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "语料文件已丢失：\(record.name)"]
            )
        }

        if var metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) {
            if shouldRefreshCorpusMetadata(metadata),
               let databaseDocument = try NativeCorpusDatabaseSupport.readDocument(at: storageURL) {
                try NativeCorpusDatabaseSupport.writeDocument(
                    at: storageURL,
                    document: DecodedTextDocument(
                        text: databaseDocument.text,
                        encodingName: databaseDocument.metadata.detectedEncoding
                    ),
                    sourceType: databaseDocument.metadata.sourceType,
                    representedPath: databaseDocument.metadata.representedPath,
                    importedAt: databaseDocument.metadata.importedAt,
                    metadataProfile: databaseDocument.metadata.metadataProfile.merged(over: record.metadata)
                )
                metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) ?? metadata
            }
            return corpusInfoSummary(from: record, metadata: metadata, fallbackPath: storageURL.path)
        }

        _ = try readStoredCorpusText(at: storageURL, record: record)
        if let metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) {
            return corpusInfoSummary(from: record, metadata: metadata, fallbackPath: storageURL.path)
        }

        let content = try TextFileDecodingSupport.readTextDocument(at: storageURL).text
        let stats = NativeAnalysisEngine().runStats(text: content)
        return CorpusInfoSummary(json: [
            "corpusId": record.id,
            "title": record.name,
            "folderName": record.folderName,
            "sourceType": record.sourceType,
            "representedPath": record.representedPath.isEmpty ? storageURL.path : record.representedPath,
            "detectedEncoding": "",
            "importedAt": "",
            "tokenCount": stats.tokenCount,
            "typeCount": stats.typeCount,
            "sentenceCount": stats.sentenceCount,
            "paragraphCount": stats.paragraphCount,
            "characterCount": content.count,
            "ttr": stats.ttr,
            "sttr": stats.sttr,
            "metadata": record.metadata.jsonObject
        ])
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) throws -> LibraryCorpusItem {
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }

        corpora[index].metadata = metadata
        let storageURL = corporaDirectoryURL.appendingPathComponent(corpora[index].storageFileName)
        if fileManager.fileExists(atPath: storageURL.path) {
            _ = try readStoredCorpusText(at: storageURL, record: corpora[index])
            try NativeCorpusDatabaseSupport.updateMetadata(at: storageURL, metadataProfile: metadata)
        }
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool
    ) throws -> LibraryImportResult {
        var folders = try loadFolders()
        var corpora = try loadCorpora()
        var imported: [NativeCorpusRecord] = []
        var skippedCount = 0

        let requests = try expandImportRequests(paths: paths, preserveHierarchy: preserveHierarchy, folders: &folders)
        let requestedFolder = resolvedFolder(for: folderId, folders: folders)

        for request in requests {
            do {
                let document = try TextFileDecodingSupport.readImportedTextDocument(at: request.sourceURL)
                let folder = request.folder ?? requestedFolder
                let record = try writeImportedCorpus(
                    sourceURL: request.sourceURL,
                    document: document,
                    folder: folder
                )
                corpora.append(record)
                imported.append(record)
            } catch {
                skippedCount += 1
            }
        }

        try saveFolders(folders)
        try saveCorpora(corpora)

        return LibraryImportResult(json: [
            "importedCount": imported.count,
            "skippedCount": skippedCount,
            "importedItems": imported.map(\.jsonObject)
        ])
    }

    func renameCorpus(corpusId: String, newName: String) throws -> LibraryCorpusItem {
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要重命名的语料。")
        }
        corpora[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func moveCorpus(corpusId: String, targetFolderId: String) throws -> LibraryCorpusItem {
        let folders = try loadFolders()
        let target = resolvedFolder(for: targetFolderId, folders: folders)
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要移动的语料。")
        }
        corpora[index].folderId = target?.id ?? ""
        corpora[index].folderName = target?.name ?? "未分类"
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func deleteCorpus(corpusId: String) throws {
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要删除的语料。")
        }
        let record = corpora.remove(at: index)
        try moveStorageToRecycle(for: record)
        var recycle = try loadRecycleEntries()
        recycle.append(
            NativeRecycleRecord(
                recycleEntryId: UUID().uuidString,
                type: "corpus",
                deletedAt: timestamp(),
                name: record.name,
                originalFolderName: record.folderName,
                sourceType: record.sourceType,
                itemCount: 1,
                folder: nil,
                corpora: [record]
            )
        )
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
    }

    func createFolder(name: String) throws -> LibraryFolderItem {
        var folders = try loadFolders()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = NativeFolderRecord(id: UUID().uuidString, name: trimmed.isEmpty ? "未命名文件夹" : trimmed)
        folders.append(folder)
        try saveFolders(folders)
        return folder.libraryItem
    }

    func renameFolder(folderId: String, newName: String) throws -> LibraryFolderItem {
        var folders = try loadFolders()
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else {
            throw missingItemError("未找到要重命名的文件夹。")
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        folders[folderIndex].name = trimmed.isEmpty ? folders[folderIndex].name : trimmed

        var corpora = try loadCorpora()
        for index in corpora.indices where corpora[index].folderId == folderId {
            corpora[index].folderName = folders[folderIndex].name
        }

        try saveFolders(folders)
        try saveCorpora(corpora)
        return folders[folderIndex].libraryItem
    }

    func deleteFolder(folderId: String) throws {
        var folders = try loadFolders()
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else {
            throw missingItemError("未找到要删除的文件夹。")
        }
        let folder = folders.remove(at: folderIndex)

        var corpora = try loadCorpora()
        let removedCorpora = corpora.filter { $0.folderId == folder.id }
        corpora.removeAll { $0.folderId == folder.id }
        for corpus in removedCorpora {
            try moveStorageToRecycle(for: corpus)
        }

        var recycle = try loadRecycleEntries()
        recycle.append(
            NativeRecycleRecord(
                recycleEntryId: UUID().uuidString,
                type: "folder",
                deletedAt: timestamp(),
                name: folder.name,
                originalFolderName: folder.name,
                sourceType: "folder",
                itemCount: removedCorpora.count,
                folder: folder,
                corpora: removedCorpora
            )
        )

        try saveFolders(folders)
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
    }

    func restoreRecycleEntry(recycleEntryId: String) throws {
        var recycle = try loadRecycleEntries()
        guard let index = recycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要恢复的回收站项目。")
        }
        let entry = recycle.remove(at: index)

        var folders = try loadFolders()
        if let folder = entry.folder, !folders.contains(where: { $0.id == folder.id }) {
            folders.append(folder)
        }

        var corpora = try loadCorpora()
        for var corpus in entry.corpora {
            if let folder = entry.folder {
                corpus.folderId = folder.id
                corpus.folderName = folder.name
            }
            try restoreStorageFromRecycle(for: corpus)
            corpora.removeAll { $0.id == corpus.id }
            corpora.append(corpus)
        }

        try saveFolders(folders)
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        var recycle = try loadRecycleEntries()
        guard let index = recycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要彻底删除的回收站项目。")
        }
        let entry = recycle.remove(at: index)
        for corpus in entry.corpora {
            let recyclePath = recycleDirectoryURL.appendingPathComponent(corpus.storageFileName)
            try? fileManager.removeItem(at: recyclePath)
        }
        try saveRecycleEntries(recycle)
    }

    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary {
        let destinationRoot = URL(fileURLWithPath: destinationPath, isDirectory: true)
        let backupDir = destinationRoot.appendingPathComponent("WordZMac-backup-\(compactTimestamp())", isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try copyDirectoryContents(from: rootURL, to: backupDir)

        let corpora = try loadCorpora()
        let folders = try loadFolders()
        return LibraryBackupSummary(json: [
            "backupDir": backupDir.path,
            "folderCount": folders.count,
            "corpusCount": corpora.count
        ])
    }

    func restoreLibrary(sourcePath: String) throws -> LibraryRestoreSummary {
        let sourceRoot = URL(fileURLWithPath: sourcePath, isDirectory: true)
        guard fileManager.fileExists(atPath: sourceRoot.path) else {
            throw missingItemError("备份目录不存在。")
        }

        let previousBackup = rootURL.deletingLastPathComponent()
            .appendingPathComponent("restore-backup-\(compactTimestamp())", isDirectory: true)
        try fileManager.createDirectory(at: previousBackup, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: rootURL.path) {
            try copyDirectoryContents(from: rootURL, to: previousBackup)
        }

        try removeDirectoryContents(at: rootURL)
        try copyDirectoryContents(from: sourceRoot, to: rootURL)
        invalidateCaches()
        try ensureInitialized()

        let corpora = try loadCorpora()
        let folders = try loadFolders()
        return LibraryRestoreSummary(json: [
            "restoredFromDir": sourceRoot.path,
            "previousLibraryBackupDir": previousBackup.path,
            "folderCount": folders.count,
            "corpusCount": corpora.count
        ])
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        var corpora = try loadCorpora()
        let folders = try loadFolders()
        let checkedCorpora = corpora.count
        let checkedFolders = folders.count

        var quarantinedCorpora = 0
        corpora.removeAll { corpus in
            let storageURL = corporaDirectoryURL.appendingPathComponent(corpus.storageFileName)
            let isReadable = fileManager.fileExists(atPath: storageURL.path) && isStoredCorpusReadable(at: storageURL)
            if !isReadable {
                quarantinedCorpora += 1
            }
            return !isReadable
        }

        try saveCorpora(corpora)

        return LibraryRepairSummary(json: [
            "summary": [
                "repairedManifest": quarantinedCorpora > 0,
                "repairedFolders": 0,
                "repairedCorpora": quarantinedCorpora,
                "recoveredCorpusMeta": 0,
                "quarantinedFolders": 0,
                "quarantinedCorpora": quarantinedCorpora,
                "checkedFolders": checkedFolders,
                "checkedCorpora": checkedCorpora
            ],
            "quarantineDir": recycleDirectoryURL.path
        ])
    }

    private func loadFolders() throws -> [NativeFolderRecord] {
        if let cachedFolders {
            return cachedFolders
        }
        let folders = try readIfPresent([NativeFolderRecord].self, from: foldersURL) ?? []
        cachedFolders = folders
        return folders
    }

    private func saveFolders(_ folders: [NativeFolderRecord]) throws {
        cachedFolders = folders
        try write(folders, to: foldersURL)
    }

    private func loadCorpora() throws -> [NativeCorpusRecord] {
        if let cachedCorpora {
            return cachedCorpora
        }
        var corpora = try readIfPresent([NativeCorpusRecord].self, from: corporaURL) ?? []
        if try migrateStorageFileNames(in: &corpora, directoryURL: corporaDirectoryURL) {
            try saveCorpora(corpora)
        }
        cachedCorpora = corpora
        return corpora
    }

    private func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        cachedCorpora = corpora
        try write(corpora, to: corporaURL)
    }

    private func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        if let cachedRecycleEntries {
            return cachedRecycleEntries
        }
        var entries = try readIfPresent([NativeRecycleRecord].self, from: recycleURL) ?? []
        if try migrateStorageFileNames(in: &entries) {
            try saveRecycleEntries(entries)
        }
        cachedRecycleEntries = entries
        return entries
    }

    private func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        cachedRecycleEntries = entries
        try write(entries, to: recycleURL)
    }

    private func loadWorkspacePersistedSnapshot() throws -> NativePersistedWorkspaceSnapshot {
        if let cachedWorkspaceSnapshot {
            return cachedWorkspaceSnapshot
        }
        let snapshot = try readIfPresent(NativePersistedWorkspaceSnapshot.self, from: workspaceURL) ?? .empty
        cachedWorkspaceSnapshot = snapshot
        return snapshot
    }

    private func loadPersistedUISettings() throws -> NativePersistedUISettings {
        if let cachedUISettings {
            return cachedUISettings
        }
        let settings = try readIfPresent(NativePersistedUISettings.self, from: uiSettingsURL) ?? .default
        cachedUISettings = settings
        return settings
    }

    private func writeImportedCorpus(
        sourceURL: URL,
        document: DecodedTextDocument,
        folder: NativeFolderRecord?
    ) throws -> NativeCorpusRecord {
        let sourceType = sourceURL.pathExtension.lowercased().isEmpty ? "txt" : sourceURL.pathExtension.lowercased()
        let id = UUID().uuidString
        let storageFileName = "\(id).db"
        let storageURL = corporaDirectoryURL.appendingPathComponent(storageFileName)
        try NativeCorpusDatabaseSupport.writeDocument(
            at: storageURL,
            document: document,
            sourceType: sourceType,
            representedPath: sourceURL.path,
            importedAt: timestamp(),
            metadataProfile: .empty
        )
        return NativeCorpusRecord(
            id: id,
            name: sourceURL.deletingPathExtension().lastPathComponent,
            folderId: folder?.id ?? "",
            folderName: folder?.name ?? "未分类",
            sourceType: sourceType,
            representedPath: sourceURL.path,
            storageFileName: storageFileName,
            metadata: .empty
        )
    }

    private func expandImportRequests(
        paths: [String],
        preserveHierarchy: Bool,
        folders: inout [NativeFolderRecord]
    ) throws -> [NativeImportRequest] {
        var requests: [NativeImportRequest] = []
        for rawPath in paths {
            let sourceURL = URL(fileURLWithPath: rawPath)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let baseFolder = preserveHierarchy
                    ? ensureFolder(named: sourceURL.lastPathComponent, folders: &folders)
                    : nil
                let enumerator = fileManager.enumerator(
                    at: sourceURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let nextURL = enumerator?.nextObject() as? URL {
                    let values = try nextURL.resourceValues(forKeys: [.isRegularFileKey])
                    guard values.isRegularFile == true else { continue }
                    requests.append(NativeImportRequest(sourceURL: nextURL, folder: baseFolder))
                }
            } else {
                requests.append(NativeImportRequest(sourceURL: sourceURL, folder: nil))
            }
        }
        return requests
    }

    private func ensureFolder(named name: String, folders: inout [NativeFolderRecord]) -> NativeFolderRecord {
        if let existing = folders.first(where: { $0.name == name }) {
            return existing
        }
        let created = NativeFolderRecord(id: UUID().uuidString, name: name)
        folders.append(created)
        return created
    }

    private func resolvedFolder(for folderId: String, folders: [NativeFolderRecord]) -> NativeFolderRecord? {
        guard !folderId.isEmpty else { return nil }
        return folders.first(where: { $0.id == folderId })
    }

    private func moveStorageToRecycle(for record: NativeCorpusRecord) throws {
        let sourceURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: sourceURL.path) {
            try? fileManager.removeItem(at: recycleURL)
            try fileManager.moveItem(at: sourceURL, to: recycleURL)
        }
    }

    private func restoreStorageFromRecycle(for record: NativeCorpusRecord) throws {
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: recycleURL.path) {
            try? fileManager.removeItem(at: storageURL)
            try fileManager.moveItem(at: recycleURL, to: storageURL)
        }
    }

    private func copyDirectoryContents(from source: URL, to destination: URL) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try? fileManager.removeItem(at: target)
            try fileManager.copyItem(at: item, to: target)
        }
    }

    private func removeDirectoryContents(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }

    private func missingItemError(_ message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusStore",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    private func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }

    private func compactTimestamp() -> String {
        NativeDateFormatting.compactTimestampString(from: Date())
    }

    private func migrateStorageFileNames(
        in corpora: inout [NativeCorpusRecord],
        directoryURL: URL
    ) throws -> Bool {
        var migrated = false
        for index in corpora.indices {
            let normalized = try migrateStorageFileNameIfNeeded(
                corpora[index].storageFileName,
                directoryURL: directoryURL
            )
            if normalized != corpora[index].storageFileName {
                corpora[index].storageFileName = normalized
                migrated = true
            }
        }
        return migrated
    }

    private func migrateStorageFileNames(in entries: inout [NativeRecycleRecord]) throws -> Bool {
        var migrated = false
        for entryIndex in entries.indices {
            if try migrateStorageFileNames(in: &entries[entryIndex].corpora, directoryURL: recycleDirectoryURL) {
                migrated = true
            }
        }
        return migrated
    }

    private func migrateStorageFileNameIfNeeded(_ storageFileName: String, directoryURL: URL) throws -> String {
        let normalized = normalizedStorageFileName(for: storageFileName)
        guard normalized != storageFileName else {
            return storageFileName
        }

        let legacyURL = directoryURL.appendingPathComponent(storageFileName)
        let normalizedURL = directoryURL.appendingPathComponent(normalized)
        if fileManager.fileExists(atPath: legacyURL.path),
           !fileManager.fileExists(atPath: normalizedURL.path) {
            try fileManager.moveItem(at: legacyURL, to: normalizedURL)
        }
        return normalized
    }

    private func normalizedStorageFileName(for storageFileName: String) -> String {
        let storageURL = URL(fileURLWithPath: storageFileName)
        let stem = storageURL.deletingPathExtension().lastPathComponent
        return "\(stem).db"
    }

    private func readStoredCorpusText(at url: URL, record: NativeCorpusRecord) throws -> String {
        if let document = try NativeCorpusDatabaseSupport.readDocument(at: url) {
            return document.text
        }

        if let document = try readStoredCorpusDocumentIfPresent(at: url) {
            let decoded = DecodedTextDocument(text: document.text, encodingName: document.detectedEncoding)
            try NativeCorpusDatabaseSupport.writeDocument(
                at: url,
                document: decoded,
                sourceType: document.sourceType,
                representedPath: document.representedPath,
                importedAt: document.importedAt,
                metadataProfile: record.metadata
            )
            return document.text
        }

        let decoded = try TextFileDecodingSupport.readTextDocument(at: url)
        try NativeCorpusDatabaseSupport.writeDocument(
            at: url,
            document: decoded,
            sourceType: record.sourceType,
            representedPath: record.representedPath,
            importedAt: timestamp(),
            metadataProfile: record.metadata
        )
        return decoded.text
    }

    private func readStoredCorpusDocumentIfPresent(at url: URL) throws -> NativeStoredCorpusDocument? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try? decoder.decode(NativeStoredCorpusDocument.self, from: data)
    }

    private func shouldRefreshCorpusMetadata(_ metadata: NativeStoredCorpusMetadata) -> Bool {
        metadata.ttr == 0 && metadata.tokenCount > 0
    }

    private func corpusInfoSummary(
        from record: NativeCorpusRecord,
        metadata: NativeStoredCorpusMetadata,
        fallbackPath: String
    ) -> CorpusInfoSummary {
        CorpusInfoSummary(json: [
            "corpusId": record.id,
            "title": record.name,
            "folderName": record.folderName,
            "sourceType": metadata.sourceType.isEmpty ? record.sourceType : metadata.sourceType,
            "representedPath": metadata.representedPath.isEmpty ? (record.representedPath.isEmpty ? fallbackPath : record.representedPath) : metadata.representedPath,
            "detectedEncoding": metadata.detectedEncoding,
            "importedAt": metadata.importedAt,
            "tokenCount": metadata.tokenCount,
            "typeCount": metadata.typeCount,
            "sentenceCount": metadata.sentenceCount,
            "paragraphCount": metadata.paragraphCount,
            "characterCount": metadata.characterCount,
            "ttr": metadata.ttr > 0 ? metadata.ttr : fallbackTTR(typeCount: metadata.typeCount, tokenCount: metadata.tokenCount),
            "sttr": metadata.sttr,
            "metadata": metadata.metadataProfile.merged(over: record.metadata).jsonObject
        ])
    }

    private func fallbackTTR(typeCount: Int, tokenCount: Int) -> Double {
        guard tokenCount > 0 else { return 0 }
        return Double(typeCount) / Double(tokenCount)
    }

    private func isStoredCorpusReadable(at url: URL) -> Bool {
        if let databaseDocument = try? NativeCorpusDatabaseSupport.readDocument(at: url) {
            return !databaseDocument.text.isEmpty || databaseDocument.metadata.characterCount == 0
        }
        if (try? readStoredCorpusDocumentIfPresent(at: url)) != nil {
            return true
        }
        return (try? TextFileDecodingSupport.readTextDocument(at: url)) != nil
    }

    private func readIfPresent<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private func invalidateCaches() {
        isInitialized = false
        cachedFolders = nil
        cachedCorpora = nil
        cachedRecycleEntries = nil
        cachedWorkspaceSnapshot = nil
        cachedUISettings = nil
    }
}

private struct NativeImportRequest {
    let sourceURL: URL
    let folder: NativeFolderRecord?
}

private struct NativeStoredCorpusDocument: Codable, Equatable {
    let schemaVersion: Int
    let importedAt: String
    let sourceType: String
    let representedPath: String
    let detectedEncoding: String
    let text: String
}

private struct NativeFolderRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String

    var libraryItem: LibraryFolderItem {
        LibraryFolderItem(json: [
            "id": id,
            "name": name
        ])
    }
}

private struct NativeCorpusRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var folderId: String
    var folderName: String
    var sourceType: String
    var representedPath: String
    var storageFileName: String
    var metadata: CorpusMetadataProfile

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case folderId
        case folderName
        case sourceType
        case representedPath
        case storageFileName
        case metadata
    }

    init(
        id: String,
        name: String,
        folderId: String,
        folderName: String,
        sourceType: String,
        representedPath: String,
        storageFileName: String,
        metadata: CorpusMetadataProfile
    ) {
        self.id = id
        self.name = name
        self.folderId = folderId
        self.folderName = folderName
        self.sourceType = sourceType
        self.representedPath = representedPath
        self.storageFileName = storageFileName
        self.metadata = metadata
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        folderId = try container.decode(String.self, forKey: .folderId)
        folderName = try container.decode(String.self, forKey: .folderName)
        sourceType = try container.decode(String.self, forKey: .sourceType)
        representedPath = try container.decode(String.self, forKey: .representedPath)
        storageFileName = try container.decode(String.self, forKey: .storageFileName)
        metadata = try container.decodeIfPresent(CorpusMetadataProfile.self, forKey: .metadata) ?? .empty
    }

    var libraryItem: LibraryCorpusItem {
        LibraryCorpusItem(json: jsonObject)
    }

    var jsonObject: JSONObject {
        [
            "id": id,
            "name": name,
            "folderId": folderId,
            "folderName": folderName,
            "sourceType": sourceType,
            "representedPath": representedPath,
            "metadata": metadata.jsonObject
        ]
    }
}

private struct NativeRecycleRecord: Codable, Equatable, Identifiable {
    let recycleEntryId: String
    let type: String
    let deletedAt: String
    let name: String
    let originalFolderName: String
    let sourceType: String
    let itemCount: Int
    let folder: NativeFolderRecord?
    var corpora: [NativeCorpusRecord]

    var id: String { recycleEntryId }

    var recycleItem: RecycleBinEntry {
        RecycleBinEntry(json: [
            "recycleEntryId": recycleEntryId,
            "type": type,
            "deletedAt": deletedAt,
            "name": name,
            "originalFolderName": originalFolderName,
            "sourceType": sourceType,
            "itemCount": itemCount
        ])
    }
}

private struct NativePersistedWorkspaceSnapshot: Codable, Equatable {
    let currentTab: String
    let currentLibraryFolderId: String
    let corpusIds: [String]
    let corpusNames: [String]
    let searchQuery: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let compareReferenceCorpusID: String
    let compareSelectedCorpusIDs: [String]
    let ngramSize: String
    let ngramPageSize: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String
    let topicsMinTopicSize: String
    let topicsIncludeOutliers: Bool
    let topicsPageSize: String
    let topicsActiveTopicID: String
    let wordCloudLimit: Int
    let frequencyNormalizationUnit: FrequencyNormalizationUnit
    let frequencyRangeMode: FrequencyRangeMode
    let chiSquareA: String
    let chiSquareB: String
    let chiSquareC: String
    let chiSquareD: String
    let chiSquareUseYates: Bool

    private enum CodingKeys: String, CodingKey {
        case currentTab
        case currentLibraryFolderId
        case corpusIds
        case corpusNames
        case searchQuery
        case searchOptions
        case stopwordFilter
        case compareReferenceCorpusID
        case compareSelectedCorpusIDs
        case ngramSize
        case ngramPageSize
        case kwicLeftWindow
        case kwicRightWindow
        case collocateLeftWindow
        case collocateRightWindow
        case collocateMinFreq
        case topicsMinTopicSize
        case topicsIncludeOutliers
        case topicsPageSize
        case topicsActiveTopicID
        case wordCloudLimit
        case frequencyNormalizationUnit
        case frequencyRangeMode
        case chiSquareA
        case chiSquareB
        case chiSquareC
        case chiSquareD
        case chiSquareUseYates
    }

    static let empty = NativePersistedWorkspaceSnapshot(
        currentTab: "stats",
        currentLibraryFolderId: "all",
        corpusIds: [],
        corpusNames: [],
        searchQuery: "",
        searchOptions: .default,
        stopwordFilter: .default,
        compareReferenceCorpusID: "",
        compareSelectedCorpusIDs: [],
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
        wordCloudLimit: 80,
        frequencyNormalizationUnit: FrequencyMetricDefinition.default.normalizationUnit,
        frequencyRangeMode: FrequencyMetricDefinition.default.rangeMode,
        chiSquareA: "",
        chiSquareB: "",
        chiSquareC: "",
        chiSquareD: "",
        chiSquareUseYates: false
    )

    init(
        currentTab: String,
        currentLibraryFolderId: String,
        corpusIds: [String],
        corpusNames: [String],
        searchQuery: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        compareReferenceCorpusID: String,
        compareSelectedCorpusIDs: [String],
        ngramSize: String,
        ngramPageSize: String,
        kwicLeftWindow: String,
        kwicRightWindow: String,
        collocateLeftWindow: String,
        collocateRightWindow: String,
        collocateMinFreq: String,
        topicsMinTopicSize: String,
        topicsIncludeOutliers: Bool,
        topicsPageSize: String,
        topicsActiveTopicID: String,
        wordCloudLimit: Int,
        frequencyNormalizationUnit: FrequencyNormalizationUnit,
        frequencyRangeMode: FrequencyRangeMode,
        chiSquareA: String,
        chiSquareB: String,
        chiSquareC: String,
        chiSquareD: String,
        chiSquareUseYates: Bool
    ) {
        self.currentTab = currentTab
        self.currentLibraryFolderId = currentLibraryFolderId
        self.corpusIds = corpusIds
        self.corpusNames = corpusNames
        self.searchQuery = searchQuery
        self.searchOptions = searchOptions
        self.stopwordFilter = stopwordFilter
        self.compareReferenceCorpusID = compareReferenceCorpusID
        self.compareSelectedCorpusIDs = compareSelectedCorpusIDs
        self.ngramSize = ngramSize
        self.ngramPageSize = ngramPageSize
        self.kwicLeftWindow = kwicLeftWindow
        self.kwicRightWindow = kwicRightWindow
        self.collocateLeftWindow = collocateLeftWindow
        self.collocateRightWindow = collocateRightWindow
        self.collocateMinFreq = collocateMinFreq
        self.topicsMinTopicSize = topicsMinTopicSize
        self.topicsIncludeOutliers = topicsIncludeOutliers
        self.topicsPageSize = topicsPageSize
        self.topicsActiveTopicID = topicsActiveTopicID
        self.wordCloudLimit = wordCloudLimit
        self.frequencyNormalizationUnit = frequencyNormalizationUnit
        self.frequencyRangeMode = frequencyRangeMode
        self.chiSquareA = chiSquareA
        self.chiSquareB = chiSquareB
        self.chiSquareC = chiSquareC
        self.chiSquareD = chiSquareD
        self.chiSquareUseYates = chiSquareUseYates
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.currentTab = try container.decodeIfPresent(String.self, forKey: .currentTab) ?? "stats"
        self.currentLibraryFolderId = try container.decodeIfPresent(String.self, forKey: .currentLibraryFolderId) ?? "all"
        self.corpusIds = try container.decodeIfPresent([String].self, forKey: .corpusIds) ?? []
        self.corpusNames = try container.decodeIfPresent([String].self, forKey: .corpusNames) ?? []
        self.searchQuery = try container.decodeIfPresent(String.self, forKey: .searchQuery) ?? ""
        self.searchOptions = try container.decodeIfPresent(SearchOptionsState.self, forKey: .searchOptions) ?? .default
        self.stopwordFilter = try container.decodeIfPresent(StopwordFilterState.self, forKey: .stopwordFilter) ?? .default
        self.compareReferenceCorpusID = try container.decodeIfPresent(String.self, forKey: .compareReferenceCorpusID) ?? ""
        self.compareSelectedCorpusIDs = try container.decodeIfPresent([String].self, forKey: .compareSelectedCorpusIDs) ?? []
        self.ngramSize = try container.decodeIfPresent(String.self, forKey: .ngramSize) ?? "2"
        self.ngramPageSize = try container.decodeIfPresent(String.self, forKey: .ngramPageSize) ?? "10"
        self.kwicLeftWindow = try container.decodeIfPresent(String.self, forKey: .kwicLeftWindow) ?? "5"
        self.kwicRightWindow = try container.decodeIfPresent(String.self, forKey: .kwicRightWindow) ?? "5"
        self.collocateLeftWindow = try container.decodeIfPresent(String.self, forKey: .collocateLeftWindow) ?? "5"
        self.collocateRightWindow = try container.decodeIfPresent(String.self, forKey: .collocateRightWindow) ?? "5"
        self.collocateMinFreq = try container.decodeIfPresent(String.self, forKey: .collocateMinFreq) ?? "1"
        self.topicsMinTopicSize = try container.decodeIfPresent(String.self, forKey: .topicsMinTopicSize) ?? "2"
        self.topicsIncludeOutliers = try container.decodeIfPresent(Bool.self, forKey: .topicsIncludeOutliers) ?? true
        self.topicsPageSize = try container.decodeIfPresent(String.self, forKey: .topicsPageSize) ?? "50"
        self.topicsActiveTopicID = try container.decodeIfPresent(String.self, forKey: .topicsActiveTopicID) ?? ""
        self.wordCloudLimit = try container.decodeIfPresent(Int.self, forKey: .wordCloudLimit) ?? 80
        self.frequencyNormalizationUnit = try container.decodeIfPresent(FrequencyNormalizationUnit.self, forKey: .frequencyNormalizationUnit) ?? FrequencyMetricDefinition.default.normalizationUnit
        self.frequencyRangeMode = try container.decodeIfPresent(FrequencyRangeMode.self, forKey: .frequencyRangeMode) ?? FrequencyMetricDefinition.default.rangeMode
        self.chiSquareA = try container.decodeIfPresent(String.self, forKey: .chiSquareA) ?? ""
        self.chiSquareB = try container.decodeIfPresent(String.self, forKey: .chiSquareB) ?? ""
        self.chiSquareC = try container.decodeIfPresent(String.self, forKey: .chiSquareC) ?? ""
        self.chiSquareD = try container.decodeIfPresent(String.self, forKey: .chiSquareD) ?? ""
        self.chiSquareUseYates = try container.decodeIfPresent(Bool.self, forKey: .chiSquareUseYates) ?? false
    }

    var workspaceSnapshot: WorkspaceSnapshotSummary {
        WorkspaceSnapshotSummary(json: [
            "currentTab": currentTab,
            "currentLibraryFolderId": currentLibraryFolderId,
            "workspace": [
                "corpusIds": corpusIds,
                "corpusNames": corpusNames
            ],
            "search": [
                "query": searchQuery,
                "options": searchOptions.asJSONObject(),
                "stopwordFilter": stopwordFilter.asJSONObject()
            ],
            "compare": [
                "referenceCorpusID": compareReferenceCorpusID,
                "selectedCorpusIDs": compareSelectedCorpusIDs
            ],
            "ngram": [
                "size": ngramSize,
                "pageSize": ngramPageSize
            ],
            "kwic": [
                "leftWindow": kwicLeftWindow,
                "rightWindow": kwicRightWindow
            ],
            "collocate": [
                "leftWindow": collocateLeftWindow,
                "rightWindow": collocateRightWindow,
                "minFreq": collocateMinFreq
            ],
            "topics": [
                "minTopicSize": topicsMinTopicSize,
                "includeOutliers": topicsIncludeOutliers,
                "pageSize": topicsPageSize,
                "activeTopicID": topicsActiveTopicID
            ],
            "wordCloud": [
                "limit": wordCloudLimit
            ],
            "frequencyMetrics": [
                "normalizationUnit": frequencyNormalizationUnit.rawValue,
                "rangeMode": frequencyRangeMode.rawValue
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
}

private struct NativePersistedUISettings: Codable, Equatable {
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool

    static let `default` = NativePersistedUISettings(
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false
    )

    var uiSettings: UISettingsSnapshot {
        UISettingsSnapshot(
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging
        )
    }
}
