import Foundation

@MainActor
final class NativeWorkspaceRepository: WorkspaceRepository, TopicProgressReportingRepository, LibraryImportProgressReportingRepository, LibraryCorpusCleaningProgressReportingRepository, CorpusSetManagingRepository, AnalysisPresetManagingRepository {
    let core: NativeWorkspaceRepositoryCore

    init(rootURL: URL = EnginePaths.defaultUserDataURL()) {
        self.core = NativeWorkspaceRepositoryCore(rootURL: rootURL)
    }
}

actor NativeWorkspaceRepositoryCore {
    var rootURL: URL
    var storage: any WorkspaceStorage
    let analysisRuntime: NativeAnalysisRuntime
    let topicEngine: NativeTopicEngine
    let analysisResultCache = NativeAnalysisResultCache(
        maxEntries: 32,
        maxEntriesByKind: [
            "compare": 8,
            "plot": 12,
            "sentiment": 8,
            "kwic": 12,
            "collocate": 12,
            "locator": 12
        ]
    )
    var inFlightAnalysisTasks: [NativeAnalysisResultCacheKey: Task<Result<InFlightAnalysisValue, Error>, Never>] = [:]
    var openedCorpusCache: [String: OpenedCorpus] = [:]
    var corpusInfoCache: [String: CorpusInfoSummary] = [:]
    var storedFrequencyArtifactsByCorpusID: [String: StoredFrequencyArtifact] = [:]
    var storedFrequencyArtifactsByTextDigest: [String: StoredFrequencyArtifact] = [:]
    var storedTokenizedArtifactsByCorpusID: [String: StoredTokenizedArtifact] = [:]
    var storedTokenizedArtifactsByTextDigest: [String: StoredTokenizedArtifact] = [:]
    var storedTokenPositionIndexesByCorpusID: [String: StoredTokenPositionIndexArtifact] = [:]
    var storedTokenPositionIndexesByTextDigest: [String: StoredTokenPositionIndexArtifact] = [:]
    var storedCorpusIDsByTextDigest: [String: String] = [:]

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.storage = NativeCorpusStore(rootURL: rootURL)
        self.analysisRuntime = NativeAnalysisRuntime()
        self.topicEngine = NativeTopicEngine()
    }
}
