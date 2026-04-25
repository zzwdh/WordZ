import Foundation

enum SentimentReviewOverlaySupport {
    static func makePresentationResult(
        rawResult: SentimentRunResult,
        reviewSamples: [SentimentReviewSample]
    ) -> SentimentPresentationResult {
        let latestSamplesByKey = Dictionary(
            uniqueKeysWithValues: latestSamples(reviewSamples).map { ($0.matchKey, $0) }
        )

        let effectiveRows = rawResult.rows.map { row -> SentimentEffectiveRow in
            let matchKey = SentimentReviewMatchKey.make(request: rawResult.request, row: row)
            guard let sample = latestSamplesByKey[matchKey] else {
                return SentimentEffectiveRow(
                    rawRow: row,
                    effectiveLabel: row.finalLabel,
                    effectiveScores: row.scoreTriple,
                    reviewDecision: nil,
                    reviewStatus: .unreviewed,
                    reviewNote: nil,
                    reviewedAt: nil,
                    reviewSampleID: nil
                )
            }

            return SentimentEffectiveRow(
                rawRow: row,
                effectiveLabel: sample.effectiveLabel,
                effectiveScores: sample.effectiveScores,
                reviewDecision: sample.decision,
                reviewStatus: sample.reviewStatus,
                reviewNote: sample.reviewNote,
                reviewedAt: sample.updatedAt,
                reviewSampleID: sample.id
            )
        }

        return SentimentPresentationResult(
            rawResult: rawResult,
            effectiveRows: effectiveRows,
            effectiveOverallSummary: makeSummary(
                id: rawResult.overallSummary.id,
                title: rawResult.overallSummary.title,
                rows: effectiveRows
            ),
            effectiveGroupSummaries: makeGroupSummaries(
                effectiveRows: effectiveRows,
                fallbackGroupSummaries: rawResult.groupSummaries
            ),
            reviewSummary: makeReviewSummary(effectiveRows: effectiveRows)
        )
    }

    static func makeReviewSample(
        decision: SentimentReviewDecision,
        row: SentimentRowResult,
        result: SentimentRunResult,
        note: String?,
        timestamp: String,
        existingSample: SentimentReviewSample? = nil
    ) -> SentimentReviewSample {
        SentimentReviewSample(
            id: existingSample?.id ?? UUID().uuidString,
            matchKey: SentimentReviewMatchKey.make(request: result.request, row: row),
            decision: decision,
            rawLabel: row.finalLabel,
            rawScores: row.scoreTriple,
            reviewNote: normalizedNote(note),
            createdAt: existingSample?.createdAt ?? timestamp,
            updatedAt: timestamp,
            backendKind: result.backendKind,
            backendRevision: result.backendRevision,
            domainPackID: result.request.resolvedDomainPackID,
            ruleProfileID: result.request.ruleProfile.id,
            calibrationProfileRevision: result.calibrationProfileRevision,
            activePackIDs: result.activePackIDs
        )
    }

    private static func latestSamples(_ reviewSamples: [SentimentReviewSample]) -> [SentimentReviewSample] {
        let grouped = Dictionary(grouping: reviewSamples, by: \.matchKey)
        return grouped.values.compactMap { samples in
            samples.max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.id < rhs.id
                }
                return lhs.updatedAt < rhs.updatedAt
            }
        }
    }

    private static func makeReviewSummary(
        effectiveRows: [SentimentEffectiveRow]
    ) -> SentimentReviewSummary {
        let reviewedCount = effectiveRows.filter { $0.reviewStatus != .unreviewed }.count
        let confirmedRawCount = effectiveRows.filter { $0.reviewStatus == .confirmed }.count
        let overriddenCount = effectiveRows.filter { $0.reviewStatus == .overridden }.count
        let pendingHardCaseCount = effectiveRows.filter { row in
            row.reviewStatus == .unreviewed &&
                (row.rawRow.diagnostics.reviewFlags.isEmpty == false || row.rawRow.mixedEvidence)
        }
        .count

        return SentimentReviewSummary(
            reviewedCount: reviewedCount,
            confirmedRawCount: confirmedRawCount,
            overriddenCount: overriddenCount,
            pendingHardCaseCount: pendingHardCaseCount
        )
    }

    private static func makeGroupSummaries(
        effectiveRows: [SentimentEffectiveRow],
        fallbackGroupSummaries: [SentimentAggregateSummary]
    ) -> [SentimentAggregateSummary] {
        let groupedRows = Dictionary(grouping: effectiveRows) { row in
            SentimentGroupKey(
                id: row.rawRow.groupID ?? "",
                title: row.rawRow.groupTitle ?? ""
            )
        }

        let orderedKeys = groupedRows.keys.sorted { lhs, rhs in
            if lhs.title == rhs.title {
                return lhs.id < rhs.id
            }
            return lhs.title < rhs.title
        }

        if !orderedKeys.isEmpty {
            return orderedKeys.map { key in
                makeSummary(
                    id: key.id.isEmpty ? key.title : key.id,
                    title: key.title.isEmpty
                        ? wordZText("未分组", "Ungrouped", mode: .system)
                        : key.title,
                    rows: groupedRows[key] ?? []
                )
            }
        }

        return fallbackGroupSummaries
    }

    private static func makeSummary(
        id: String,
        title: String,
        rows: [SentimentEffectiveRow]
    ) -> SentimentAggregateSummary {
        let totalTexts = rows.count
        let positiveCount = rows.filter { $0.effectiveLabel == .positive }.count
        let neutralCount = rows.filter { $0.effectiveLabel == .neutral }.count
        let negativeCount = rows.filter { $0.effectiveLabel == .negative }.count
        let total = Double(max(totalTexts, 1))
        let averagePositivity = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.effectiveScores.positivityScore } / Double(rows.count)
        let averageNeutrality = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.effectiveScores.neutralityScore } / Double(rows.count)
        let averageNegativity = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.effectiveScores.negativityScore } / Double(rows.count)
        let averageNetScore = rows.isEmpty ? 0 : rows.reduce(0) { $0 + $1.effectiveScores.netScore } / Double(rows.count)

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

    private static func normalizedNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct SentimentGroupKey: Hashable {
    let id: String
    let title: String
}
