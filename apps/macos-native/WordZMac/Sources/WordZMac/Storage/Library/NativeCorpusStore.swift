import Foundation

final class NativeCorpusStore: WorkspaceStorage, ProgressReportingLibraryStore, CorpusCleaningProgressReportingLibraryStore, CorpusSetManagingLibraryStore {
    let rootURL: URL
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    var isInitialized = false
    var cachedFolders: [NativeFolderRecord]?
    var cachedCorpora: [NativeCorpusRecord]?
    var cachedCorpusSets: [NativeCorpusSetRecord]?
    var cachedAnalysisPresets: [NativeAnalysisPresetRecord]?
    var cachedKeywordSavedLists: [KeywordSavedList]?
    var cachedConcordanceSavedSets: [ConcordanceSavedSet]?
    var cachedEvidenceItems: [EvidenceItem]?
    var cachedRecycleEntries: [NativeRecycleRecord]?
    var cachedWorkspaceSnapshot: NativePersistedWorkspaceSnapshot?
    var cachedUISettings: NativePersistedUISettings?

    var corporaDirectoryURL: URL { rootURL.appendingPathComponent("corpora", isDirectory: true) }
    var recycleDirectoryURL: URL { rootURL.appendingPathComponent("recycle", isDirectory: true) }
    var foldersURL: URL { rootURL.appendingPathComponent("folders.json") }
    var corporaURL: URL { rootURL.appendingPathComponent("corpora.json") }
    var corpusSetsURL: URL { rootURL.appendingPathComponent("corpus-sets.json") }
    var recycleURL: URL { rootURL.appendingPathComponent("recycle.json") }
    var analysisPresetsURL: URL { rootURL.appendingPathComponent("analysis-presets.json") }
    var keywordSavedListsURL: URL { rootURL.appendingPathComponent("keyword-saved-lists.json") }
    var concordanceSavedSetsURL: URL { rootURL.appendingPathComponent("concordance-saved-sets.json") }
    var evidenceItemsURL: URL { rootURL.appendingPathComponent("evidence-items.json") }
    var workspaceURL: URL { rootURL.appendingPathComponent("workspace-state.json") }
    var uiSettingsURL: URL { rootURL.appendingPathComponent("ui-settings.json") }
    var manifestStore: CorpusManifestStore {
        CorpusManifestStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            foldersURL: foldersURL,
            corporaURL: corporaURL,
            corpusSetsURL: corpusSetsURL,
            recycleURL: recycleURL,
            corporaDirectoryURL: corporaDirectoryURL,
            recycleDirectoryURL: recycleDirectoryURL,
            migrator: CorpusStorageMigrator(fileManager: fileManager)
        )
    }
    var snapshotStore: NativeWorkspaceSnapshotStore {
        NativeWorkspaceSnapshotStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            workspaceURL: workspaceURL,
            uiSettingsURL: uiSettingsURL
        )
    }
    var analysisPresetStore: NativeAnalysisPresetStore {
        NativeAnalysisPresetStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            presetsURL: analysisPresetsURL
        )
    }
    var keywordSavedListStore: NativeKeywordSavedListStore {
        NativeKeywordSavedListStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            listsURL: keywordSavedListsURL
        )
    }
    var concordanceSavedSetStore: NativeConcordanceSavedSetStore {
        NativeConcordanceSavedSetStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            setsURL: concordanceSavedSetsURL
        )
    }
    var evidenceItemStore: NativeEvidenceItemStore {
        NativeEvidenceItemStore(
            fileManager: fileManager,
            encoder: encoder,
            decoder: decoder,
            itemsURL: evidenceItemsURL
        )
    }

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    func writeImportedCorpus(
        sourceURL: URL,
        document: DecodedTextDocument,
        folder: NativeFolderRecord?,
        storageDirectoryURL: URL? = nil,
        importedAt: String? = nil,
        metadataProfile: CorpusMetadataProfile = .empty
    ) throws -> NativeCorpusRecord {
        let sourceType = sourceURL.pathExtension.lowercased().isEmpty ? "txt" : sourceURL.pathExtension.lowercased()
        let id = UUID().uuidString
        let storageFileName = "\(id).db"
        let destinationDirectory = storageDirectoryURL ?? corporaDirectoryURL
        let storageURL = destinationDirectory.appendingPathComponent(storageFileName)
        let cleaned = CorpusAutoCleaningSupport.clean(document.text)
        let trimmedCleanedText = cleaned.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCleanedText.isEmpty else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "自动清洗后未保留可用文本：\(sourceURL.lastPathComponent)。"]
            )
        }
        let cleanedAt = importedAt ?? timestamp()
        let cleaningSummary = CorpusAutoCleaningSupport.makeReportSummary(
            from: cleaned,
            cleanedAt: cleanedAt
        )
        try NativeCorpusDatabaseSupport.writeDocument(
            at: storageURL,
            document: DecodedTextDocument(
                text: cleaned.cleanedText,
                encodingName: document.encodingName
            ),
            sourceType: sourceType,
            representedPath: sourceURL.path,
            importedAt: cleanedAt,
            metadataProfile: metadataProfile,
            rawText: cleaned.rawText,
            cleaningSummary: cleaningSummary
        )
        return NativeCorpusRecord(
            id: id,
            name: sourceURL.deletingPathExtension().lastPathComponent,
            folderId: folder?.id ?? "",
            folderName: folder?.name ?? "未分类",
            sourceType: sourceType,
            representedPath: sourceURL.path,
            storageFileName: storageFileName,
            metadata: metadataProfile,
            cleaningSummary: cleaningSummary
        )
    }
}

struct NativeImportRequest {
    let sourceURL: URL
    let folder: NativeFolderRecord?
}

struct NativeExpandedImportRequests {
    let requests: [NativeImportRequest]
    let skippedItems: [LibraryImportFailureItem]
}

struct NativeStagedImportArtifact {
    let record: NativeCorpusRecord
    let stagedStorageURL: URL
}
