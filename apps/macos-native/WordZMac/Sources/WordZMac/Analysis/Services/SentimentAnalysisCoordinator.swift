import Foundation

private struct SentimentGroupKey: Hashable {
    let id: String
    let title: String
}

struct SentimentAnalysisCoordinator {
    let lexiconAnalyzer: SentimentAnalyzing
    let coreMLAnalyzer: SentimentAnalyzing?

    func analyze(_ request: SentimentRunRequest) -> SentimentRunResult {
        switch request.backend {
        case .lexicon:
            return analyzeWithLexicon(request)
        case .coreML:
            if let coreMLAnalyzer {
                do {
                    return try coreMLAnalyzer.analyze(request)
                } catch {
                    return analyzeWithLexicon(request)
                }
            }
            return analyzeWithLexicon(request)
        }
    }

    private func analyzeWithLexicon(_ request: SentimentRunRequest) -> SentimentRunResult {
        do {
            return try lexiconAnalyzer.analyze(request)
        } catch {
            return SentimentResultAggregation.makeRunResult(
                request: request,
                backendKind: .lexicon,
                backendRevision: "lexicon-rules-v2",
                resourceRevision: "sentiment-pack-unavailable",
                supportsEvidenceHits: true,
                rows: [],
                lexiconVersion: ""
            )
        }
    }
}

enum SentimentResultAggregation {
    static func makeRunResult(
        request: SentimentRunRequest,
        backendKind: SentimentBackendKind,
        backendRevision: String,
        resourceRevision: String,
        supportsEvidenceHits: Bool,
        rows: [SentimentRowResult],
        lexiconVersion: String
    ) -> SentimentRunResult {
        let overallSummary = makeSummary(
            id: "overall",
            title: wordZText("总体", "Overall", mode: .system),
            rows: rows
        )
        let groupedRows = Dictionary(grouping: rows) {
            SentimentGroupKey(id: $0.groupID ?? "", title: $0.groupTitle ?? "")
        }
        let groupSummaries = groupedRows.keys
            .sorted { lhs, rhs in
                if lhs.title == rhs.title {
                    return lhs.id < rhs.id
                }
                return lhs.title < rhs.title
            }
            .map { key in
                makeSummary(
                    id: key.id.isEmpty ? key.title : key.id,
                    title: key.title.isEmpty
                        ? wordZText("未分组", "Ungrouped", mode: .system)
                        : key.title,
                    rows: groupedRows[key] ?? []
                )
            }

        return SentimentRunResult(
            request: request,
            backendKind: backendKind,
            backendRevision: backendRevision,
            resourceRevision: resourceRevision,
            supportsEvidenceHits: supportsEvidenceHits,
            rows: rows,
            overallSummary: overallSummary,
            groupSummaries: groupSummaries,
            lexiconVersion: lexiconVersion
        )
    }

    static func makeSummary(
        id: String,
        title: String,
        rows: [SentimentRowResult]
    ) -> SentimentAggregateSummary {
        let totalTexts = rows.count
        let positiveCount = rows.filter { $0.finalLabel == .positive }.count
        let neutralCount = rows.filter { $0.finalLabel == .neutral }.count
        let negativeCount = rows.filter { $0.finalLabel == .negative }.count
        let total = Double(max(totalTexts, 1))
        let averagePositivity = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.positivityScore } / Double(rows.count)
        let averageNeutrality = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.neutralityScore } / Double(rows.count)
        let averageNegativity = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.negativityScore } / Double(rows.count)
        let averageNetScore = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.netScore } / Double(rows.count)

        return SentimentAggregateSummary(
            id: id,
            title: title,
            totalTexts: totalTexts,
            positiveCount: positiveCount,
            neutralCount: neutralCount,
            negativeCount: negativeCount,
            positiveRatio: Double(positiveCount) / total,
            neutralRatio: Double(neutralCount) / total,
            negativeRatio: Double(negativeCount) / total,
            averagePositivity: averagePositivity,
            averageNeutrality: averageNeutrality,
            averageNegativity: averageNegativity,
            averageNetScore: averageNetScore
        )
    }
}

