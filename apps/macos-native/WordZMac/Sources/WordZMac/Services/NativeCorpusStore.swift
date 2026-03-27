import Foundation

struct NativeCorpusStore {
    private let rootURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

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
                "Swift native preview",
                "本地语料库与分析结果已不再依赖 Node sidecar。"
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
        let persisted = try readIfPresent(NativePersistedWorkspaceSnapshot.self, from: workspaceURL) ?? .empty
        return persisted.workspaceSnapshot
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
            ngramSize: draft.ngramSize,
            ngramPageSize: draft.ngramPageSize,
            kwicLeftWindow: draft.kwicLeftWindow,
            kwicRightWindow: draft.kwicRightWindow,
            collocateLeftWindow: draft.collocateLeftWindow,
            collocateRightWindow: draft.collocateRightWindow,
            collocateMinFreq: draft.collocateMinFreq
        )
        try write(persisted, to: workspaceURL)
    }

    func loadUISettings() throws -> UISettingsSnapshot {
        let persisted = try readIfPresent(NativePersistedUISettings.self, from: uiSettingsURL) ?? .default
        return persisted.uiSettings
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) throws {
        try write(
            NativePersistedUISettings(
                zoom: snapshot.zoom,
                fontScale: snapshot.fontScale,
                fontFamily: snapshot.fontFamily,
                showWelcomeScreen: snapshot.showWelcomeScreen,
                restoreWorkspace: snapshot.restoreWorkspace,
                debugLogging: snapshot.debugLogging
            ),
            to: uiSettingsURL
        )
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
        let content = try readTextFile(at: storageURL)
        return OpenedCorpus(json: [
            "mode": "saved",
            "filePath": record.representedPath.isEmpty ? storageURL.path : record.representedPath,
            "displayName": record.name,
            "content": content,
            "sourceType": record.sourceType
        ])
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
                let content = try readTextFile(at: request.sourceURL)
                let folder = request.folder ?? requestedFolder
                let record = try writeImportedCorpus(
                    sourceURL: request.sourceURL,
                    content: content,
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
            let exists = fileManager.fileExists(atPath: corporaDirectoryURL.appendingPathComponent(corpus.storageFileName).path)
            if !exists {
                quarantinedCorpora += 1
            }
            return !exists
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
        try readIfPresent([NativeFolderRecord].self, from: foldersURL) ?? []
    }

    private func saveFolders(_ folders: [NativeFolderRecord]) throws {
        try write(folders, to: foldersURL)
    }

    private func loadCorpora() throws -> [NativeCorpusRecord] {
        try readIfPresent([NativeCorpusRecord].self, from: corporaURL) ?? []
    }

    private func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        try write(corpora, to: corporaURL)
    }

    private func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        try readIfPresent([NativeRecycleRecord].self, from: recycleURL) ?? []
    }

    private func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        try write(entries, to: recycleURL)
    }

    private func readTextFile(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let encodings: [String.Encoding] = [
            .utf8,
            .utf16,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32,
            .ascii,
            .isoLatin1,
            .windowsCP1252,
            .gb18030
        ]
        for encoding in encodings {
            if let string = String(data: data, encoding: encoding), !string.isEmpty {
                return string
            }
        }
        let fallback = String(decoding: data, as: UTF8.self)
        if !fallback.isEmpty {
            return fallback
        }
        throw NSError(
            domain: "WordZMac.NativeCorpusStore",
            code: 415,
            userInfo: [NSLocalizedDescriptionKey: "暂不支持读取该语料文件格式：\(url.lastPathComponent)"]
        )
    }

    private func writeImportedCorpus(
        sourceURL: URL,
        content: String,
        folder: NativeFolderRecord?
    ) throws -> NativeCorpusRecord {
        let sourceType = sourceURL.pathExtension.lowercased().isEmpty ? "txt" : sourceURL.pathExtension.lowercased()
        let id = UUID().uuidString
        let storageFileName = "\(id).txt"
        let storageURL = corporaDirectoryURL.appendingPathComponent(storageFileName)
        try content.write(to: storageURL, atomically: true, encoding: .utf8)
        return NativeCorpusRecord(
            id: id,
            name: sourceURL.deletingPathExtension().lastPathComponent,
            folderId: folder?.id ?? "",
            folderName: folder?.name ?? "未分类",
            sourceType: sourceType,
            representedPath: sourceURL.path,
            storageFileName: storageFileName
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
        ISO8601DateFormatter().string(from: Date())
    }

    private func compactTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }

    private func readIfPresent<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}

private struct NativeImportRequest {
    let sourceURL: URL
    let folder: NativeFolderRecord?
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

    var libraryItem: LibraryCorpusItem {
        LibraryCorpusItem(json: jsonObject)
    }

    var jsonObject: JSONObject {
        [
            "id": id,
            "name": name,
            "folderId": folderId,
            "folderName": folderName,
            "sourceType": sourceType
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
    let corpora: [NativeCorpusRecord]

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
    let ngramSize: String
    let ngramPageSize: String
    let kwicLeftWindow: String
    let kwicRightWindow: String
    let collocateLeftWindow: String
    let collocateRightWindow: String
    let collocateMinFreq: String

    static let empty = NativePersistedWorkspaceSnapshot(
        currentTab: "stats",
        currentLibraryFolderId: "all",
        corpusIds: [],
        corpusNames: [],
        searchQuery: "",
        searchOptions: .default,
        stopwordFilter: .default,
        ngramSize: "2",
        ngramPageSize: "10",
        kwicLeftWindow: "5",
        kwicRightWindow: "5",
        collocateLeftWindow: "5",
        collocateRightWindow: "5",
        collocateMinFreq: "1"
    )

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
            ]
        ])
    }
}

private struct NativePersistedUISettings: Codable, Equatable {
    let zoom: Int
    let fontScale: Int
    let fontFamily: String
    let showWelcomeScreen: Bool
    let restoreWorkspace: Bool
    let debugLogging: Bool

    static let `default` = NativePersistedUISettings(
        zoom: 100,
        fontScale: 100,
        fontFamily: "system",
        showWelcomeScreen: true,
        restoreWorkspace: true,
        debugLogging: false
    )

    var uiSettings: UISettingsSnapshot {
        UISettingsSnapshot(
            zoom: zoom,
            fontScale: fontScale,
            fontFamily: fontFamily,
            showWelcomeScreen: showWelcomeScreen,
            restoreWorkspace: restoreWorkspace,
            debugLogging: debugLogging
        )
    }
}

private extension String.Encoding {
    static let gb18030 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
    )
}
