import Foundation

extension NativeWorkspaceRepositoryCore {
    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.kwic(
            digest: documentKey.textDigest,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if let lookup = matcher.exactLookup,
           let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest],
           let positionIndex = try storedTokenPositionIndex(forTextDigest: documentKey.textDigest) {
            let analysisRuntime = self.analysisRuntime
            let positions = positionIndex.positions(for: lookup)
            return try await cachedAnalysisResult(for: key) {
                await analysisRuntime.runKWIC(
                    artifact: artifact,
                    positions: positions,
                    leftWindow: leftWindow,
                    rightWindow: rightWindow
                )
            }
        }
        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            if let candidateSentenceIDs = try storedSentenceCandidateIDs(
                forTextDigest: documentKey.textDigest,
                matcher: matcher
            ) {
                return try await cachedAnalysisResult(for: key) {
                    try await analysisRuntime.runKWIC(
                        artifact: artifact,
                        candidateSentenceIDs: candidateSentenceIDs,
                        keyword: keyword,
                        leftWindow: leftWindow,
                        rightWindow: rightWindow,
                        searchOptions: searchOptions
                    )
                }
            }
            return try await cachedAnalysisResult(for: key) {
                try await analysisRuntime.runKWIC(
                    artifact: artifact,
                    keyword: keyword,
                    leftWindow: leftWindow,
                    rightWindow: rightWindow,
                    searchOptions: searchOptions
                )
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            try await analysisRuntime.runKWIC(
                text: text,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.collocate(
            digest: documentKey.textDigest,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
        let matcher = SearchTextMatcher(query: keyword, options: searchOptions)
        if let lookup = matcher.exactLookup,
           let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest],
           let positionIndex = try storedTokenPositionIndex(forTextDigest: documentKey.textDigest) {
            let analysisRuntime = self.analysisRuntime
            let positions = positionIndex.positions(for: lookup)
            return try await cachedAnalysisResult(for: key) {
                await analysisRuntime.runCollocate(
                    artifact: artifact,
                    positions: positions,
                    leftWindow: leftWindow,
                    rightWindow: rightWindow,
                    minFreq: minFreq
                )
            }
        }
        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            if let candidateSentenceIDs = try storedSentenceCandidateIDs(
                forTextDigest: documentKey.textDigest,
                matcher: matcher
            ) {
                return try await cachedAnalysisResult(for: key) {
                    try await analysisRuntime.runCollocate(
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
            return try await cachedAnalysisResult(for: key) {
                try await analysisRuntime.runCollocate(
                    artifact: artifact,
                    keyword: keyword,
                    leftWindow: leftWindow,
                    rightWindow: rightWindow,
                    minFreq: minFreq,
                    searchOptions: searchOptions
                )
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            try await analysisRuntime.runCollocate(
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

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.locator(
            digest: documentKey.textDigest,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
        if let storedResult = try storedLocatorResult(
            forTextDigest: documentKey.textDigest,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        ) {
            return try await cachedAnalysisResult(for: key) {
                storedResult
            }
        }
        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            return try await cachedAnalysisResult(for: key) {
                await analysisRuntime.runLocator(
                    artifact: artifact,
                    sentenceId: sentenceId,
                    nodeIndex: nodeIndex,
                    leftWindow: leftWindow,
                    rightWindow: rightWindow
                )
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runLocator(
                text: text,
                sentenceId: sentenceId,
                nodeIndex: nodeIndex,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                documentKey: documentKey
            )
        }
    }
}
