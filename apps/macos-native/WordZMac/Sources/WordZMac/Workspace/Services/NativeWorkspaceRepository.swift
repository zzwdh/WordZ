import Foundation
import WordZEngine

@MainActor
final class NativeWorkspaceRepository: WorkspaceRepository, TopicProgressReportingRepository, LibraryImportProgressReportingRepository, MergedCorpusImportingRepository, LibraryCorpusCleaningProgressReportingRepository, CorpusSetManagingRepository, CorpusSetOpeningRepository, AnalysisPresetManagingRepository, MetadataFilteringLibraryRepository, FullTextSearchingLibraryRepository, StoredTokenizedArtifactReadingRepository, StoredFrequencyArtifactReadingRepository, StoredTokenPositionIndexReadingRepository {
    let core: NativeWorkspaceRepositoryCore

    init(
        rootURL: URL = EnginePaths.defaultUserDataURL(),
        seedBundledDefaultReferenceCorpora: Bool = true
    ) {
        self.core = NativeWorkspaceRepositoryCore(
            rootURL: rootURL,
            seedBundledDefaultReferenceCorpora: seedBundledDefaultReferenceCorpora
        )
    }
}

struct StoredSentenceSearchCacheKey: Hashable {
    let textDigest: String
    let phraseSignature: String
}

actor NativeWorkspaceRepositoryCore {
    var rootURL: URL
    var storage: any WorkspaceStorage
    let seedBundledDefaultReferenceCorpora: Bool
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
    var storedSentenceSearchCandidateIDsByKey: [StoredSentenceSearchCacheKey: Set<Int>] = [:]

    init(
        rootURL: URL,
        seedBundledDefaultReferenceCorpora: Bool
    ) {
        self.rootURL = rootURL
        self.seedBundledDefaultReferenceCorpora = seedBundledDefaultReferenceCorpora
        self.storage = NativeCorpusStore(
            rootURL: rootURL,
            seedBundledDefaultReferenceCorpora: seedBundledDefaultReferenceCorpora
        )
        self.analysisRuntime = NativeAnalysisRuntime()
        self.topicEngine = NativeTopicEngine()
    }
}
