import Foundation

actor NativeAnalysisRuntime {
    private let engine: NativeAnalysisEngine

    init(engine: NativeAnalysisEngine = NativeAnalysisEngine()) {
        self.engine = engine
    }

    var cachedDocumentCountForTesting: Int {
        engine.cachedDocumentCountForTesting
    }

    var cachedFrequencySummaryCountForTesting: Int {
        engine.cachedFrequencySummaryCountForTesting
    }

    func runStats(text: String, documentKey: DocumentCacheKey? = nil) async -> StatsResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runStats(text: text, documentKey: documentKey)
        }
    }

    func runTokenize(text: String, documentKey: DocumentCacheKey? = nil) async -> TokenizeResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runTokenize(text: text, documentKey: documentKey)
        }
    }

    func runTokenize(artifact: StoredTokenizedArtifact) async -> TokenizeResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runTokenize(artifact: artifact)
        }
    }

    func runNgram(text: String, n: Int, documentKey: DocumentCacheKey? = nil) async -> NgramResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runNgram(text: text, n: n, documentKey: documentKey)
        }
    }

    func runNgram(artifact: StoredTokenizedArtifact, n: Int) async -> NgramResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runNgram(artifact: artifact, n: n)
        }
    }

    func runPlot(
        text: String,
        keyword: String,
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) async throws -> PlotDocumentDistribution {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runPlot(
                text: text,
                keyword: keyword,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition]
    ) async -> PlotDocumentDistribution {
        let engine = self.engine
        return await Self.runDetached {
            engine.runPlot(
                artifact: artifact,
                positions: positions
            )
        }
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        keyword: String,
        searchOptions: SearchOptionsState
    ) async throws -> PlotDocumentDistribution {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runPlot(
                artifact: artifact,
                keyword: keyword,
                searchOptions: searchOptions
            )
        }
    }

    func runPlot(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
        keyword: String,
        searchOptions: SearchOptionsState
    ) async throws -> PlotDocumentDistribution {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runPlot(
                artifact: artifact,
                candidateSentenceIDs: candidateSentenceIDs,
                keyword: keyword,
                searchOptions: searchOptions
            )
        }
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) async throws -> KWICResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runKWIC(
                text: text,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runKWIC(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition],
        leftWindow: Int,
        rightWindow: Int
    ) async -> KWICResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runKWIC(
                artifact: artifact,
                positions: positions,
                leftWindow: leftWindow,
                rightWindow: rightWindow
            )
        }
    }

    func runKWIC(
        artifact: StoredTokenizedArtifact,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runKWIC(
                artifact: artifact,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions
            )
        }
    }

    func runKWIC(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runKWIC(
                artifact: artifact,
                candidateSentenceIDs: candidateSentenceIDs,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions
            )
        }
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState,
        documentKey: DocumentCacheKey? = nil
    ) async throws -> CollocateResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runCollocate(
                text: text,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
        positions: [StoredTokenPosition],
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int
    ) async -> CollocateResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runCollocate(
                artifact: artifact,
                positions: positions,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq
            )
        }
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runCollocate(
                artifact: artifact,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq,
                searchOptions: searchOptions
            )
        }
    }

    func runCollocate(
        artifact: StoredTokenizedArtifact,
        candidateSentenceIDs: Set<Int>,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        let engine = self.engine
        return try await Self.runDetached {
            try engine.runCollocate(
                artifact: artifact,
                candidateSentenceIDs: candidateSentenceIDs,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq,
                searchOptions: searchOptions
            )
        }
    }

    func runLocator(
        text: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int,
        documentKey: DocumentCacheKey? = nil
    ) async -> LocatorResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runLocator(
                text: text,
                sentenceId: sentenceId,
                nodeIndex: nodeIndex,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                documentKey: documentKey
            )
        }
    }

    func runLocator(
        artifact: StoredTokenizedArtifact,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) async -> LocatorResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runLocator(
                artifact: artifact,
                sentenceId: sentenceId,
                nodeIndex: nodeIndex,
                leftWindow: leftWindow,
                rightWindow: rightWindow
            )
        }
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async -> CompareResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runCompare(comparisonEntries: comparisonEntries)
        }
    }

    func runSentiment(_ request: SentimentRunRequest) async -> SentimentRunResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runSentiment(request)
        }
    }

    func runPreparedCompare(preparedCorpora: [PreparedCompareCorpus]) async -> CompareResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runPreparedCompare(preparedCorpora: preparedCorpora)
        }
    }

    func runKeywordSuite(_ request: KeywordSuiteRunRequest) async -> KeywordSuiteResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runKeywordSuite(request)
        }
    }

    func runPreparedKeywordSuite(_ request: PreparedKeywordSuiteRequest) async -> KeywordSuiteResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runPreparedKeywordSuite(request)
        }
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async -> KeywordResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runKeyword(
                targetEntry: targetEntry,
                referenceEntry: referenceEntry,
                options: options
            )
        }
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async -> ChiSquareResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
        }
    }

    func runCluster(_ request: ClusterRunRequest) async -> ClusterResult {
        let engine = self.engine
        return await Self.runDetached {
            engine.runCluster(request)
        }
    }

    private static func runDetached<T: Sendable>(
        operation: @escaping @Sendable () -> T
    ) async -> T {
        await Task.detached(priority: .userInitiated, operation: operation).value
    }

    private static func runDetached<T: Sendable>(
        operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: operation).value
    }
}
