import Foundation
@testable import WordZWorkspaceCore

struct TopicSurrogatePrecisionFixtureBundle: Decodable {
    let datasetID: String
    let corpora: [TopicSurrogatePrecisionCorpus]
}

struct TopicSurrogatePrecisionCorpus: Decodable {
    let id: String
    let minTopicSize: Int
    let expectedThemes: [String]
    let minClusterPurityProxy: Double
    let minThemeRecallProxy: Double
    let maxOutlierRatio: Double
    let minKeywordCoherenceProxy: Double
    let minBridgeAssignmentProxy: Double?
    let minStabilityScore: Double?
    let ignoredLabels: [String]
    let bridgeLabelTargets: [String: [String]]
    let keywordHints: [String: [String]]
    let documents: [TopicSurrogatePrecisionDocument]
}

struct TopicSurrogatePrecisionDocument: Decodable {
    let id: String
    let label: String
    let text: String
    let repeatCount: Int?
}

struct TopicSurrogatePrecisionReport {
    let corpusID: String
    let strategy: TopicClusteringStrategy
    let nonOutlierClusterCount: Int
    let outlierRatio: Double
    let clusterPurityProxy: Double
    let themeRecallProxy: Double
    let keywordCoherenceProxy: Double
    let bridgeAssignmentProxy: Double
    let stabilityScore: Double?
    let representedThemes: Set<String>
    let keywordTerms: Set<String>
    let worstClusterSummary: String

    var summaryLine: String {
        let stabilityText = stabilityScore.map { String(format: "%.3f", $0) } ?? "n/a"
        return String(
            format: "%@ strategy=%@ clusters=%d outlier=%.3f purityProxy=%.3f recallProxy=%.3f keywordCoherence=%.3f bridge=%.3f stability=%@ worst=%@",
            corpusID,
            strategy.rawValue,
            nonOutlierClusterCount,
            outlierRatio,
            clusterPurityProxy,
            themeRecallProxy,
            keywordCoherenceProxy,
            bridgeAssignmentProxy,
            stabilityText,
            worstClusterSummary
        )
    }

    func withStabilityScore(_ score: Double) -> TopicSurrogatePrecisionReport {
        TopicSurrogatePrecisionReport(
            corpusID: corpusID,
            strategy: strategy,
            nonOutlierClusterCount: nonOutlierClusterCount,
            outlierRatio: outlierRatio,
            clusterPurityProxy: clusterPurityProxy,
            themeRecallProxy: themeRecallProxy,
            keywordCoherenceProxy: keywordCoherenceProxy,
            bridgeAssignmentProxy: bridgeAssignmentProxy,
            stabilityScore: score,
            representedThemes: representedThemes,
            keywordTerms: keywordTerms,
            worstClusterSummary: worstClusterSummary
        )
    }
}

enum TopicSurrogateCorpusTransform {
    case identity
    case reorderedWithNoiseAndDuplication
}

enum TopicSurrogatePrecisionCatalog {
    static func load(filePath: StaticString = #filePath) throws -> [TopicSurrogatePrecisionCorpus] {
        let fixtureURL = Bundle.module.url(
            forResource: "topic-surrogate-precision-v1",
            withExtension: "json",
            subdirectory: "Fixtures/Topics"
        ) ?? URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Topics", isDirectory: true)
            .appendingPathComponent("topic-surrogate-precision-v1.json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode(TopicSurrogatePrecisionFixtureBundle.self, from: data).corpora
    }
}

enum TopicSurrogatePrecisionHarness {
    static func analyze(
        corpus: TopicSurrogatePrecisionCorpus,
        transform: TopicSurrogateCorpusTransform = .identity,
        engine: NativeTopicEngine = NativeTopicEngine()
    ) async throws -> TopicSurrogatePrecisionReport {
        let documents = expandedDocuments(for: corpus, transform: transform)
        let text = documents.map(\.text).joined(separator: "\n\n")
        let result = try await engine.analyze(
            text: text,
            options: TopicAnalysisOptions(
                minTopicSize: corpus.minTopicSize,
                partitionScoringProfile: .precisionFirst
            ),
            progress: nil
        )
        return makeReport(
            corpus: corpus,
            documents: documents,
            result: result
        )
    }

    static func analyzeWithStability(
        corpus: TopicSurrogatePrecisionCorpus
    ) async throws -> TopicSurrogatePrecisionReport {
        let engine = NativeTopicEngine()
        let baseline = try await analyze(corpus: corpus, engine: engine)
        let perturbed = try await analyze(
            corpus: corpus,
            transform: .reorderedWithNoiseAndDuplication,
            engine: engine
        )
        return baseline.withStabilityScore(stabilityScore(baseline, perturbed))
    }

    private static func expandedDocuments(
        for corpus: TopicSurrogatePrecisionCorpus,
        transform: TopicSurrogateCorpusTransform
    ) -> [TopicBenchmarkExpandedDocument] {
        var instances: [(label: String, text: String)] = []
        for document in corpus.documents {
            for _ in 0..<max(1, document.repeatCount ?? 1) {
                instances.append((document.label, document.text))
            }
        }

        if transform == .reorderedWithNoiseAndDuplication {
            instances = instances.enumerated()
                .sorted { lhs, rhs in
                    let lhsKey = (lhs.offset % 3, -lhs.offset)
                    let rhsKey = (rhs.offset % 3, -rhs.offset)
                    return lhsKey < rhsKey
                }
                .map(\.element)
            instances.append(
                contentsOf: instances
                    .filter { corpus.expectedThemes.contains($0.label) }
                    .prefix(max(1, corpus.expectedThemes.count))
            )
            instances.append(
                contentsOf: [
                    (
                        label: "noise",
                        text: "Appendix boilerplate records table formatting, page numbers, and citation placeholders for later review."
                    ),
                    (
                        label: "noise",
                        text: "Method notes describe sampling dates, export filenames, and spreadsheet cleanup without adding topical evidence."
                    )
                ]
            )
        }

        return instances.enumerated().map { offset, instance in
            TopicBenchmarkExpandedDocument(
                paragraphIndex: offset + 1,
                label: instance.label,
                text: instance.text
            )
        }
    }

    private static func makeReport(
        corpus: TopicSurrogatePrecisionCorpus,
        documents: [TopicBenchmarkExpandedDocument],
        result: TopicAnalysisResult
    ) -> TopicSurrogatePrecisionReport {
        let expectedThemes = Set(corpus.expectedThemes)
        let labelByParagraph = Dictionary(uniqueKeysWithValues: documents.map { ($0.paragraphIndex, $0.label) })
        let nonOutlierClusters = result.clusters.filter { !$0.isOutlier }
        let segmentsByTopicID = Dictionary(grouping: result.segments.filter { !$0.isOutlier }, by: \.topicID)
        let outlierRatio = result.totalSegments == 0
            ? 0
            : Double(result.outlierCount) / Double(result.totalSegments)

        var clusteredThemeSegments = 0
        var majorityThemeSegments = 0
        var representedThemes = Set<String>()
        var keywordCoherenceNumerator = 0.0
        var keywordCoherenceWeight = 0.0
        var worstCluster = "none"
        var worstPurity = Double.infinity

        for cluster in nonOutlierClusters {
            let segments = segmentsByTopicID[cluster.id] ?? []
            let themeLabels = segments
                .compactMap { labelByParagraph[$0.paragraphIndex] }
                .filter { expectedThemes.contains($0) }
            guard !themeLabels.isEmpty else { continue }

            let counts = Dictionary(grouping: themeLabels, by: { $0 }).mapValues(\.count)
            guard let majority = counts.max(by: { lhs, rhs in
                lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
            }) else {
                continue
            }

            clusteredThemeSegments += themeLabels.count
            majorityThemeSegments += majority.value
            representedThemes.insert(majority.key)

            let clusterPurity = Double(majority.value) / Double(themeLabels.count)
            if clusterPurity < worstPurity {
                worstPurity = clusterPurity
                let mixedLabels = counts
                    .sorted { lhs, rhs in lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value }
                    .map { "\($0.key):\($0.value)" }
                    .joined(separator: ",")
                worstCluster = "\(cluster.id)[\(mixedLabels)]"
            }

            let coherence = keywordCoherenceScore(
                keywords: cluster.keywordTerms,
                hints: corpus.keywordHints[majority.key] ?? []
            )
            keywordCoherenceNumerator += coherence * Double(themeLabels.count)
            keywordCoherenceWeight += Double(themeLabels.count)
        }

        let clusterPurityProxy = clusteredThemeSegments == 0
            ? 0
            : Double(majorityThemeSegments) / Double(clusteredThemeSegments)
        let themeRecallProxy = expectedThemes.isEmpty
            ? 0
            : Double(representedThemes.count) / Double(expectedThemes.count)
        let keywordCoherenceProxy = keywordCoherenceWeight == 0
            ? 0
            : keywordCoherenceNumerator / keywordCoherenceWeight

        return TopicSurrogatePrecisionReport(
            corpusID: corpus.id,
            strategy: result.diagnostics.clusteringStrategy,
            nonOutlierClusterCount: nonOutlierClusters.count,
            outlierRatio: outlierRatio,
            clusterPurityProxy: clusterPurityProxy,
            themeRecallProxy: themeRecallProxy,
            keywordCoherenceProxy: keywordCoherenceProxy,
            bridgeAssignmentProxy: bridgeAssignmentProxy(
                corpus: corpus,
                result: result,
                labelByParagraph: labelByParagraph,
                segmentsByTopicID: segmentsByTopicID,
                expectedThemes: expectedThemes
            ),
            stabilityScore: nil,
            representedThemes: representedThemes,
            keywordTerms: Set(nonOutlierClusters.flatMap(\.keywordTerms).map(normalizedTerm)),
            worstClusterSummary: worstCluster
        )
    }

    private static func bridgeAssignmentProxy(
        corpus: TopicSurrogatePrecisionCorpus,
        result: TopicAnalysisResult,
        labelByParagraph: [Int: String],
        segmentsByTopicID: [String: [TopicSegmentRow]],
        expectedThemes: Set<String>
    ) -> Double {
        guard !corpus.bridgeLabelTargets.isEmpty else { return 1 }

        var checked = 0
        var accepted = 0
        for segment in result.segments {
            guard let label = labelByParagraph[segment.paragraphIndex],
                  let allowedThemes = corpus.bridgeLabelTargets[label] else {
                continue
            }

            checked += 1
            if segment.isOutlier {
                accepted += 1
                continue
            }

            let clusterThemeLabels = (segmentsByTopicID[segment.topicID] ?? [])
                .compactMap { labelByParagraph[$0.paragraphIndex] }
                .filter { expectedThemes.contains($0) }
            let clusterThemeCounts = Dictionary(
                grouping: clusterThemeLabels,
                by: { label in label }
            )
            .mapValues { labels in labels.count }
            let majority = clusterThemeCounts.max { lhs, rhs in
                lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
            }
            if let majority, allowedThemes.contains(majority.key) {
                accepted += 1
            }
        }

        return checked == 0 ? 1 : Double(accepted) / Double(checked)
    }

    private static func keywordCoherenceScore(
        keywords: [String],
        hints: [String]
    ) -> Double {
        let normalizedKeywords = keywords.map(normalizedTerm)
        let normalizedHints = hints.map(normalizedTerm).filter { !$0.isEmpty }
        guard !normalizedKeywords.isEmpty, !normalizedHints.isEmpty else { return 0 }

        let hits = normalizedHints.filter { hint in
            normalizedKeywords.contains { keyword in
                keyword.contains(hint) || hint.contains(keyword)
            }
        }
        return min(1, Double(hits.count) / Double(min(3, normalizedHints.count)))
    }

    private static func stabilityScore(
        _ baseline: TopicSurrogatePrecisionReport,
        _ perturbed: TopicSurrogatePrecisionReport
    ) -> Double {
        let themeScore = jaccard(baseline.representedThemes, perturbed.representedThemes)
        let keywordScore = jaccard(baseline.keywordTerms, perturbed.keywordTerms)
        let maxClusters = max(1, max(baseline.nonOutlierClusterCount, perturbed.nonOutlierClusterCount))
        let clusterScore = 1 - (Double(abs(baseline.nonOutlierClusterCount - perturbed.nonOutlierClusterCount)) / Double(maxClusters))
        let purityScore = max(0, 1 - abs(baseline.clusterPurityProxy - perturbed.clusterPurityProxy))
        return (themeScore * 0.45) + (keywordScore * 0.25) + (clusterScore * 0.2) + (purityScore * 0.1)
    }

    private static func jaccard(_ lhs: Set<String>, _ rhs: Set<String>) -> Double {
        if lhs.isEmpty && rhs.isEmpty { return 1 }
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }
        return Double(lhs.intersection(rhs).count) / Double(union.count)
    }

    private static func normalizedTerm(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9 ]", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
