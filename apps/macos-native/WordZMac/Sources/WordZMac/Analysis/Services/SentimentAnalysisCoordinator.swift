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
                    let modelResult = try coreMLAnalyzer.analyze(request)
                    guard request.resolvedDomainPackID == .news else {
                        return modelResult
                    }
                    let lexiconResult = analyzeWithLexicon(request)
                    return mergeHybridResult(
                        modelResult: modelResult,
                        lexiconResult: lexiconResult
                    )
                } catch {
                    return analyzeWithLexiconFallback(request)
                }
            }
            return analyzeWithLexiconFallback(request)
        }
    }

    private func analyzeWithLexicon(_ request: SentimentRunRequest) -> SentimentRunResult {
        do {
            return try lexiconAnalyzer.analyze(request)
        } catch {
            return SentimentResultAggregation.makeRunResult(
                request: request,
                backendKind: .lexicon,
                backendRevision: "lexicon-rules-v3",
                resourceRevision: "sentiment-pack-unavailable",
                supportsEvidenceHits: true,
                rows: [],
                lexiconVersion: ""
            )
        }
    }

    private func analyzeWithLexiconFallback(_ request: SentimentRunRequest) -> SentimentRunResult {
        let result = analyzeWithLexicon(request)
        let fallbackRows = result.rows.map { row in
            var diagnostics = row.diagnostics
            diagnostics.inferencePath = .fallback
            return SentimentRowResult(
                id: row.id,
                sourceID: row.sourceID,
                sourceTitle: row.sourceTitle,
                groupID: row.groupID,
                groupTitle: row.groupTitle,
                text: row.text,
                positivityScore: row.positivityScore,
                negativityScore: row.negativityScore,
                neutralityScore: row.neutralityScore,
                finalLabel: row.finalLabel,
                netScore: row.netScore,
                evidence: row.evidence,
                evidenceCount: row.evidenceCount,
                mixedEvidence: row.mixedEvidence,
                diagnostics: diagnostics,
                sentenceID: row.sentenceID,
                tokenIndex: row.tokenIndex
            )
        }
        return SentimentRunResult(
            request: result.request,
            backendKind: result.backendKind,
            backendRevision: result.backendRevision,
            resourceRevision: result.resourceRevision,
            providerID: result.providerID,
            providerFamily: result.providerFamily,
            supportsEvidenceHits: result.supportsEvidenceHits,
            rows: fallbackRows,
            overallSummary: result.overallSummary,
            groupSummaries: result.groupSummaries,
            lexiconVersion: result.lexiconVersion,
            activeRuleProfileRevision: result.activeRuleProfileRevision,
            activePackIDs: result.activePackIDs,
            calibrationProfileRevision: result.calibrationProfileRevision,
            userLexiconBundleIDs: result.userLexiconBundleIDs
        )
    }

    private func mergeHybridResult(
        modelResult: SentimentRunResult,
        lexiconResult: SentimentRunResult
    ) -> SentimentRunResult {
        let lexiconRowsByID = Dictionary(uniqueKeysWithValues: lexiconResult.rows.map { ($0.id, $0) })
        var usedHybridRow = false
        let mergedRows = modelResult.rows.map { modelRow in
            guard let lexiconRow = lexiconRowsByID[modelRow.id],
                  shouldUseHybridRow(modelRow: modelRow, lexiconRow: lexiconRow) else {
                return modelRow
            }
            usedHybridRow = true
            return hybridRow(lexiconRow: lexiconRow, modelRow: modelRow)
        }

        guard usedHybridRow else {
            return modelResult
        }

        return SentimentResultAggregation.makeRunResult(
            request: modelResult.request,
            backendKind: .coreML,
            backendRevision: modelResult.backendRevision,
            resourceRevision: modelResult.resourceRevision,
            providerID: modelResult.providerID,
            providerFamily: modelResult.providerFamily,
            supportsEvidenceHits: true,
            rows: mergedRows,
            lexiconVersion: lexiconResult.lexiconVersion,
            activeRuleProfileRevision: modelResult.activeRuleProfileRevision,
            activePackIDs: lexiconResult.activePackIDs,
            calibrationProfileRevision: modelResult.calibrationProfileRevision,
            userLexiconBundleIDs: modelResult.userLexiconBundleIDs
        )
    }

    private func shouldUseHybridRow(
        modelRow: SentimentRowResult,
        lexiconRow: SentimentRowResult
    ) -> Bool {
        let hasAttributedSpeechSignal = lexiconRow.diagnostics.reviewFlags.contains(.quoted)
            || lexiconRow.diagnostics.reviewFlags.contains(.reported)
        let lowConfidence = (modelRow.diagnostics.confidence ?? 1.0) < 0.62
        let lowMargin = (modelRow.diagnostics.topMargin ?? 1.0) < 0.16
        return hasAttributedSpeechSignal || lowConfidence || lowMargin
    }

    private func hybridRow(
        lexiconRow: SentimentRowResult,
        modelRow: SentimentRowResult
    ) -> SentimentRowResult {
        var diagnostics = lexiconRow.diagnostics
        diagnostics.inferencePath = .hybrid
        diagnostics.providerID = modelRow.diagnostics.providerID
        diagnostics.providerFamily = modelRow.diagnostics.providerFamily
        diagnostics.modelRevision = modelRow.diagnostics.modelRevision
        diagnostics.modelInputKind = modelRow.diagnostics.modelInputKind
        diagnostics.confidence = modelRow.diagnostics.confidence
        diagnostics.topMargin = modelRow.diagnostics.topMargin
        diagnostics.scopeNotes = Array(
            Set(diagnostics.scopeNotes + ["hybrid_news_guardrail"])
        ).sorted()

        return SentimentRowResult(
            id: lexiconRow.id,
            sourceID: lexiconRow.sourceID,
            sourceTitle: lexiconRow.sourceTitle,
            groupID: lexiconRow.groupID,
            groupTitle: lexiconRow.groupTitle,
            text: lexiconRow.text,
            positivityScore: lexiconRow.positivityScore,
            negativityScore: lexiconRow.negativityScore,
            neutralityScore: lexiconRow.neutralityScore,
            finalLabel: lexiconRow.finalLabel,
            netScore: lexiconRow.netScore,
            evidence: lexiconRow.evidence,
            evidenceCount: lexiconRow.evidenceCount,
            mixedEvidence: lexiconRow.mixedEvidence,
            diagnostics: diagnostics,
            sentenceID: lexiconRow.sentenceID,
            tokenIndex: lexiconRow.tokenIndex
        )
    }
}

enum SentimentResultAggregation {
    static func makeRunResult(
        request: SentimentRunRequest,
        backendKind: SentimentBackendKind,
        backendRevision: String,
        resourceRevision: String,
        providerID: String? = nil,
        providerFamily: SentimentModelProviderFamily? = nil,
        supportsEvidenceHits: Bool,
        rows: [SentimentRowResult],
        lexiconVersion: String,
        activeRuleProfileRevision: String? = nil,
        activePackIDs: [SentimentDomainPackID] = [],
        calibrationProfileRevision: String? = nil,
        userLexiconBundleIDs: [String] = []
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
            providerID: providerID,
            providerFamily: providerFamily,
            supportsEvidenceHits: supportsEvidenceHits,
            rows: rows,
            overallSummary: overallSummary,
            groupSummaries: groupSummaries,
            lexiconVersion: lexiconVersion,
            activeRuleProfileRevision: activeRuleProfileRevision,
            activePackIDs: activePackIDs,
            calibrationProfileRevision: calibrationProfileRevision,
            userLexiconBundleIDs: userLexiconBundleIDs
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
