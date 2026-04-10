import Foundation

extension NativeCorpusStore {
    func loadFolders() throws -> [NativeFolderRecord] {
        if let cachedFolders {
            return cachedFolders
        }
        let folders = try manifestStore.loadFolders()
        cachedFolders = folders
        return folders
    }

    func saveFolders(_ folders: [NativeFolderRecord]) throws {
        cachedFolders = folders
        try manifestStore.saveFolders(folders)
    }

    func loadCorpora() throws -> [NativeCorpusRecord] {
        if let cachedCorpora {
            return cachedCorpora
        }
        let corpora = try manifestStore.loadCorpora()
        cachedCorpora = corpora
        return corpora
    }

    func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        cachedCorpora = corpora
        try manifestStore.saveCorpora(corpora)
    }

    func loadCorpusSets() throws -> [NativeCorpusSetRecord] {
        if let cachedCorpusSets {
            return cachedCorpusSets
        }
        let corpusSets = try manifestStore.loadCorpusSets()
        cachedCorpusSets = corpusSets
        return corpusSets
    }

    func saveCorpusSets(_ corpusSets: [NativeCorpusSetRecord]) throws {
        cachedCorpusSets = corpusSets
        try manifestStore.saveCorpusSets(corpusSets)
    }

    func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        if let cachedRecycleEntries {
            return cachedRecycleEntries
        }
        let entries = try manifestStore.loadRecycleEntries()
        cachedRecycleEntries = entries
        return entries
    }

    func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        cachedRecycleEntries = entries
        try manifestStore.saveRecycleEntries(entries)
    }

    func loadAnalysisPresets() throws -> [NativeAnalysisPresetRecord] {
        if let cachedAnalysisPresets {
            return cachedAnalysisPresets
        }
        let presets = try analysisPresetStore.loadPresets()
        cachedAnalysisPresets = presets
        return presets
    }

    func saveAnalysisPresets(_ presets: [NativeAnalysisPresetRecord]) throws {
        cachedAnalysisPresets = presets
        try analysisPresetStore.savePresets(presets)
    }

    func loadWorkspacePersistedSnapshot() throws -> NativePersistedWorkspaceSnapshot {
        if let cachedWorkspaceSnapshot {
            return cachedWorkspaceSnapshot
        }
        let snapshot = try snapshotStore.loadWorkspaceSnapshot()
        cachedWorkspaceSnapshot = snapshot
        return snapshot
    }

    func loadPersistedUISettings() throws -> NativePersistedUISettings {
        if let cachedUISettings {
            return cachedUISettings
        }
        let settings = try snapshotStore.loadUISettings()
        cachedUISettings = settings
        return settings
    }

    func invalidateCaches() {
        isInitialized = false
        cachedFolders = nil
        cachedCorpora = nil
        cachedCorpusSets = nil
        cachedAnalysisPresets = nil
        cachedRecycleEntries = nil
        cachedWorkspaceSnapshot = nil
        cachedUISettings = nil
    }
}
