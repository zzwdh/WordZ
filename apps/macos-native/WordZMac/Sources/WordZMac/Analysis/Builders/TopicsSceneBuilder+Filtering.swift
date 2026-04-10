import Foundation

extension TopicsSceneBuilder {
    func buildVisibleSegmentsByCluster(
        from result: TopicAnalysisResult,
        matcher: SearchTextMatcher,
        stopwordFilter: StopwordFilterState,
        summaryTermsByCluster: [String: [TopicKeywordCandidate]]
    ) -> [String: [TopicSegmentRow]] {
        guard matcher.error.isEmpty else { return [:] }
        var visibleSegmentsByCluster: [String: [TopicSegmentRow]] = [:]
        visibleSegmentsByCluster.reserveCapacity(result.clusters.count)

        for segment in result.segments {
            let keywords = (summaryTermsByCluster[segment.topicID] ?? []).map(\.term)
            let matches = TopicFilterSupport.matchesSegment(
                text: segment.text,
                query: matcher.normalizedQuery,
                options: matcher.options,
                stopword: stopwordFilter,
                keywords: keywords
            )
            if matches.matches {
                visibleSegmentsByCluster[segment.topicID, default: []].append(segment)
            }
        }

        return visibleSegmentsByCluster
    }

    func buildTotalSegmentsByCluster(
        from result: TopicAnalysisResult
    ) -> [String: Int] {
        var totals: [String: Int] = [:]
        totals.reserveCapacity(result.clusters.count)
        for segment in result.segments {
            totals[segment.topicID, default: 0] += 1
        }
        return totals
    }

    func buildRepresentativeSegmentsByCluster(
        from result: TopicAnalysisResult
    ) -> [String: [String]] {
        let segmentsByID = Dictionary(uniqueKeysWithValues: result.segments.map { ($0.id, $0.text) })
        return Dictionary(uniqueKeysWithValues: result.clusters.map { cluster in
            (
                cluster.id,
                cluster.representativeSegmentIDs.compactMap { segmentsByID[$0] }
            )
        })
    }

    func filteredSegments(
        for clusterID: String,
        in result: TopicAnalysisResult,
        matcher: SearchTextMatcher,
        stopwordFilter: StopwordFilterState
    ) -> [TopicSegmentRow] {
        guard matcher.error.isEmpty else { return [] }
        let cluster = result.cluster(for: clusterID)
        let keywords = cluster.map {
            TopicFilterSupport.summaryTerms(from: $0.keywordCandidates, filter: stopwordFilter, limit: 8).map(\.term)
        } ?? []
        return result.segments.filter { segment in
            guard segment.topicID == clusterID else { return false }
            return TopicFilterSupport.matchesSegment(
                text: segment.text,
                query: matcher.normalizedQuery,
                options: matcher.options,
                stopword: stopwordFilter,
                keywords: keywords
            ).matches
        }
    }

    func sortSegments(_ rows: [TopicSegmentRow], mode: TopicSegmentSortMode) -> [TopicSegmentRow] {
        switch mode {
        case .relevanceDescending:
            return rows.sorted {
                if $0.similarityScore == $1.similarityScore {
                    return $0.paragraphIndex < $1.paragraphIndex
                }
                return $0.similarityScore > $1.similarityScore
            }
        case .relevanceAscending:
            return rows.sorted {
                if $0.similarityScore == $1.similarityScore {
                    return $0.paragraphIndex < $1.paragraphIndex
                }
                return $0.similarityScore < $1.similarityScore
            }
        case .paragraphAscending:
            return rows.sorted { $0.paragraphIndex < $1.paragraphIndex }
        case .paragraphDescending:
            return rows.sorted { $0.paragraphIndex > $1.paragraphIndex }
        case .alphabeticalAscending:
            return rows.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        case .alphabeticalDescending:
            return rows.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedDescending }
        }
    }

    func resolveSelectedClusterID(requested: String?, available: [String]) -> String? {
        if let requested, available.contains(requested) {
            return requested
        }
        return available.first
    }
}
