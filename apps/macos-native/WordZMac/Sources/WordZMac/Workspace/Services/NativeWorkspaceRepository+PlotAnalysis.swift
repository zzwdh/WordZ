import Foundation

extension NativeWorkspaceRepositoryCore {
    func runPlot(_ request: PlotRunRequest) async throws -> PlotResult {
        let normalizedQuery = request.normalizedQuery
        guard !normalizedQuery.isEmpty else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "请输入 Plot 检索词。"]
            )
        }

        let matcher = SearchTextMatcher(query: normalizedQuery, options: request.searchOptions)
        if !matcher.error.isEmpty {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: matcher.error]
            )
        }

        let key = NativeAnalysisResultCacheKey.plot(request: request)
        let exactLookup = matcher.exactLookup
        return try await cachedAnalysisResult(for: key) {
            try await self.computePlotResult(
                request: request,
                normalizedQuery: normalizedQuery,
                exactLookup: exactLookup
            )
        }
    }

    private func computePlotResult(
        request: PlotRunRequest,
        normalizedQuery: String,
        exactLookup: StoredTokenPositionIndexArtifact.Lookup?
    ) async throws -> PlotResult {
        var rows: [PlotRow] = []
        rows.reserveCapacity(request.entries.count)

        for (index, entry) in request.entries.enumerated() {
            let distribution = try await plotDistribution(
                for: entry,
                query: normalizedQuery,
                searchOptions: request.searchOptions,
                exactLookup: exactLookup
            )
            rows.append(
                PlotRow(
                    id: entry.corpusId,
                    corpusId: entry.corpusId,
                    fileID: index,
                    filePath: entry.filePath,
                    displayName: entry.displayName,
                    fileTokens: distribution.tokenCount,
                    frequency: distribution.hitMarkers.count,
                    normalizedFrequency: plotNormalizedFrequency(
                        count: distribution.hitMarkers.count,
                        tokenCount: distribution.tokenCount
                    ),
                    hitMarkers: distribution.hitMarkers
                )
            )
        }

        let totalHits = rows.reduce(0) { $0 + $1.frequency }
        let totalFilesWithHits = rows.reduce(0) { partialResult, row in
            partialResult + (row.frequency > 0 ? 1 : 0)
        }

        return PlotResult(
            request: request,
            totalHits: totalHits,
            totalFilesWithHits: totalFilesWithHits,
            totalFiles: request.entries.count,
            rows: rows
        )
    }

    private func plotDistribution(
        for entry: PlotCorpusEntry,
        query: String,
        searchOptions: SearchOptionsState,
        exactLookup: StoredTokenPositionIndexArtifact.Lookup?
    ) async throws -> PlotDocumentDistribution {
        let documentKey = DocumentCacheKey(text: entry.content)
        try cacheStoredTokenizedArtifact(for: entry.corpusId, text: entry.content)

        if let positionIndex = try storedTokenPositionIndex(for: entry.corpusId),
           positionIndex.textDigest.isEmpty || positionIndex.textDigest == documentKey.textDigest {
            storedTokenPositionIndexesByTextDigest[documentKey.textDigest] = positionIndex
        }

        if let exactLookup,
           let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest],
           let positionIndex = try storedTokenPositionIndex(forTextDigest: documentKey.textDigest) {
            let analysisRuntime = self.analysisRuntime
            return await analysisRuntime.runPlot(
                artifact: artifact,
                positions: positionIndex.positions(for: exactLookup)
            )
        }

        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            return try await analysisRuntime.runPlot(
                artifact: artifact,
                keyword: query,
                searchOptions: searchOptions
            )
        }

        let analysisRuntime = self.analysisRuntime
        return try await analysisRuntime.runPlot(
            text: entry.content,
            keyword: query,
            searchOptions: searchOptions,
            documentKey: documentKey
        )
    }
}

private func plotNormalizedFrequency(count: Int, tokenCount: Int) -> Double {
    guard tokenCount > 0 else { return 0 }
    return (Double(count) / Double(tokenCount)) * 10_000
}
