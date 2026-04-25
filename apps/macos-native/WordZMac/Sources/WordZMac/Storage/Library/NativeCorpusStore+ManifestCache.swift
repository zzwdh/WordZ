import Foundation

extension NativeCorpusStore {
    func loadFolders() throws -> [NativeFolderRecord] {
        if let cachedFolders {
            return cachedFolders
        }
        let folders = try libraryCatalogStore.loadFolders()
        cachedFolders = folders
        return folders
    }

    func saveFolders(_ folders: [NativeFolderRecord]) throws {
        cachedFolders = folders
        try libraryCatalogStore.saveFolders(folders)
    }

    func loadCorpora() throws -> [NativeCorpusRecord] {
        if let cachedCorpora {
            return cachedCorpora
        }
        let corpora = try libraryCatalogStore.loadCorpora()
        cachedCorpora = corpora
        return corpora
    }

    func loadCorpora(folderId: String) throws -> [NativeCorpusRecord] {
        guard !folderId.isEmpty, folderId != "all" else {
            return try loadCorpora()
        }
        if let cachedCorpora {
            return cachedCorpora.filter { $0.folderId == folderId }
        }
        return try libraryCatalogStore.loadCorpora(folderId: folderId)
    }

    func loadCorpora(folderId: String, metadataFilterState: CorpusMetadataFilterState) throws -> [NativeCorpusRecord] {
        guard !metadataFilterState.isEmpty else {
            return try loadCorpora(folderId: folderId)
        }
        return try libraryCatalogStore.loadCorpora(
            folderId: folderId,
            metadataFilterState: metadataFilterState
        )
    }

    func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        cachedCorpora = corpora
        try libraryCatalogStore.saveCorpora(corpora)
    }

    func loadCorpusSets() throws -> [NativeCorpusSetRecord] {
        if let cachedCorpusSets {
            return cachedCorpusSets
        }
        let corpusSets = try libraryCatalogStore.loadCorpusSets()
        cachedCorpusSets = corpusSets
        return corpusSets
    }

    func saveCorpusSets(_ corpusSets: [NativeCorpusSetRecord]) throws {
        cachedCorpusSets = corpusSets
        try libraryCatalogStore.saveCorpusSets(corpusSets)
    }

    func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        if let cachedRecycleEntries {
            return cachedRecycleEntries
        }
        let entries = try libraryCatalogStore.loadRecycleEntries()
        cachedRecycleEntries = entries
        return entries
    }

    func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        cachedRecycleEntries = entries
        try libraryCatalogStore.saveRecycleEntries(entries)
    }

    func loadAnalysisPresets() throws -> [NativeAnalysisPresetRecord] {
        if let cachedAnalysisPresets {
            return cachedAnalysisPresets
        }
        let presets = try workspaceDatabaseStore.loadAnalysisPresets()
        cachedAnalysisPresets = presets
        return presets
    }

    func saveAnalysisPresets(_ presets: [NativeAnalysisPresetRecord]) throws {
        cachedAnalysisPresets = presets
        try workspaceDatabaseStore.saveAnalysisPresets(presets)
    }

    func loadKeywordSavedLists() throws -> [KeywordSavedList] {
        if let cachedKeywordSavedLists {
            return cachedKeywordSavedLists
        }
        let lists = try workspaceDatabaseStore.loadKeywordSavedLists()
        cachedKeywordSavedLists = lists
        return lists
    }

    func saveKeywordSavedLists(_ lists: [KeywordSavedList]) throws {
        cachedKeywordSavedLists = lists
        try workspaceDatabaseStore.saveKeywordSavedLists(lists)
    }

    func loadConcordanceSavedSets() throws -> [ConcordanceSavedSet] {
        if let cachedConcordanceSavedSets {
            return cachedConcordanceSavedSets
        }
        let sets = try workspaceDatabaseStore.loadConcordanceSavedSets()
        cachedConcordanceSavedSets = sets
        return sets
    }

    func saveConcordanceSavedSets(_ sets: [ConcordanceSavedSet]) throws {
        cachedConcordanceSavedSets = sets
        try workspaceDatabaseStore.saveConcordanceSavedSets(sets)
    }

    func loadEvidenceItems() throws -> [EvidenceItem] {
        if let cachedEvidenceItems {
            return cachedEvidenceItems
        }
        let items = try workspaceDatabaseStore.loadEvidenceItems()
        cachedEvidenceItems = items
        return items
    }

    func saveEvidenceItems(_ items: [EvidenceItem]) throws {
        cachedEvidenceItems = items
        try workspaceDatabaseStore.saveEvidenceItems(items)
    }

    func loadSentimentReviewSamples() throws -> [SentimentReviewSample] {
        if let cachedSentimentReviewSamples {
            return cachedSentimentReviewSamples
        }
        let samples = try workspaceDatabaseStore.loadSentimentReviewSamples()
        cachedSentimentReviewSamples = samples
        return samples
    }

    func saveSentimentReviewSamples(_ samples: [SentimentReviewSample]) throws {
        cachedSentimentReviewSamples = samples
        try workspaceDatabaseStore.saveSentimentReviewSamples(samples)
    }

    func loadWorkspacePersistedSnapshot() throws -> NativePersistedWorkspaceSnapshot {
        if let cachedWorkspaceSnapshot {
            return cachedWorkspaceSnapshot
        }
        let snapshot = try workspaceDatabaseStore.loadWorkspaceSnapshot()
        cachedWorkspaceSnapshot = snapshot
        return snapshot
    }

    func loadPersistedUISettings() throws -> NativePersistedUISettings {
        if let cachedUISettings {
            return cachedUISettings
        }
        let settings = try workspaceDatabaseStore.loadUISettings()
        cachedUISettings = settings
        return settings
    }

    func invalidateCaches() {
        isInitialized = false
        cachedFolders = nil
        cachedCorpora = nil
        cachedCorpusSets = nil
        cachedAnalysisPresets = nil
        cachedKeywordSavedLists = nil
        cachedConcordanceSavedSets = nil
        cachedEvidenceItems = nil
        cachedSentimentReviewSamples = nil
        cachedRecycleEntries = nil
        cachedWorkspaceSnapshot = nil
        cachedUISettings = nil
    }
}
