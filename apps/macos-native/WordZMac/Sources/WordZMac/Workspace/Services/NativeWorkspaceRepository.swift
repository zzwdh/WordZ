import Foundation

@MainActor
final class NativeWorkspaceRepository: WorkspaceRepository, TopicProgressReportingRepository, LibraryImportProgressReportingRepository, CorpusSetManagingRepository, AnalysisPresetManagingRepository {
    let core: NativeWorkspaceRepositoryCore

    init(rootURL: URL = EnginePaths.defaultUserDataURL()) {
        self.core = NativeWorkspaceRepositoryCore(rootURL: rootURL)
    }
}

actor NativeWorkspaceRepositoryCore {
    var rootURL: URL
    var storage: any WorkspaceStorage
    let analysisEngine: NativeAnalysisEngine
    let topicEngine: NativeTopicEngine
    let analysisResultCache = NativeAnalysisResultCache(
        maxEntries: 32,
        maxEntriesByKind: [
            "compare": 8,
            "kwic": 12,
            "collocate": 12,
            "locator": 12
        ]
    )
    var openedCorpusCache: [String: OpenedCorpus] = [:]
    var corpusInfoCache: [String: CorpusInfoSummary] = [:]

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.storage = NativeCorpusStore(rootURL: rootURL)
        self.analysisEngine = NativeAnalysisEngine()
        self.topicEngine = NativeTopicEngine()
    }
}
