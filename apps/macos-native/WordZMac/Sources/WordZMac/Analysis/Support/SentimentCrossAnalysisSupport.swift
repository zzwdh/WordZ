import Foundation

enum SentimentCrossAnalysisSupport {
    static func buildCompareExplainer(
        context: CompareSentimentDrilldownContext,
        presentationResult: SentimentPresentationResult,
        languageMode: AppLanguageMode
    ) -> CompareSentimentExplainer? {
        guard presentationResult.rawResult.request.source == .corpusCompare else {
            return nil
        }

        let targetRows = rows(in: "target", from: presentationResult.effectiveRows)
        let referenceRows = rows(in: "reference", from: presentationResult.effectiveRows)
        let targetSummary = makeSummary(
            id: "target",
            title: wordZText("目标语料", "Target", mode: languageMode),
            rows: targetRows
        )
        let referenceSummary = referenceRows.isEmpty
            ? nil
            : makeSummary(
                id: "reference",
                title: wordZText("参照语料", "Reference", mode: languageMode),
                rows: referenceRows
            )

        let positiveDeltaPoints = (targetSummary.positiveRatio - (referenceSummary?.positiveRatio ?? 0)) * 100
        let neutralDeltaPoints = (targetSummary.neutralRatio - (referenceSummary?.neutralRatio ?? 0)) * 100
        let negativeDeltaPoints = (targetSummary.negativeRatio - (referenceSummary?.negativeRatio ?? 0)) * 100
        let averageNetDelta = targetSummary.averageNetScore - (referenceSummary?.averageNetScore ?? 0)

        return CompareSentimentExplainer(
            focusTerm: context.focusTerm,
            headline: [
                wordZText("Compare x Sentiment", "Compare x Sentiment", mode: languageMode),
                "\(wordZText("聚焦词项", "Focus Term", mode: languageMode)): \(context.focusTerm)"
            ]
            .joined(separator: " · "),
            scopeSummary: context.scopeSummary(in: languageMode),
            targetSummary: targetSummary,
            referenceSummary: referenceSummary,
            positiveDeltaPoints: positiveDeltaPoints,
            neutralDeltaPoints: neutralDeltaPoints,
            negativeDeltaPoints: negativeDeltaPoints,
            averageNetDelta: averageNetDelta,
            targetReviewImpact: makeReviewImpact(rows: targetRows),
            referenceReviewImpact: referenceRows.isEmpty ? nil : makeReviewImpact(rows: referenceRows),
            targetTopDrivers: topDrivers(in: targetRows),
            referenceTopDrivers: topDrivers(in: referenceRows),
            targetExemplars: topExemplars(in: targetRows),
            referenceExemplars: topExemplars(in: referenceRows)
        )
    }

    static func buildTopicsExplainer(
        presentationResult: SentimentPresentationResult,
        focusedClusterID: String?,
        languageMode: AppLanguageMode
    ) -> TopicsSentimentExplainer? {
        guard presentationResult.rawResult.request.source == .topicSegments else {
            return nil
        }

        let grouped = Dictionary(grouping: presentationResult.effectiveRows) { row in
            row.rawRow.groupID ?? row.rawRow.groupTitle ?? wordZText("未分组", "Ungrouped", mode: languageMode)
        }
        let orderedGroups = orderedGroupDescriptors(
            from: presentationResult.rawResult.request.texts,
            fallbackRows: presentationResult.effectiveRows,
            languageMode: languageMode
        )
        let filteredGroups = orderedGroups.filter { descriptor in
            focusedClusterID.map { descriptor.id == $0 } ?? true
        }
        let clusters = filteredGroups.compactMap { descriptor -> TopicsSentimentClusterExplainer? in
            let rows = grouped[descriptor.id] ?? []
            guard !rows.isEmpty else { return nil }
            let summary = makeSummary(id: descriptor.id, title: descriptor.title, rows: rows)
            return TopicsSentimentClusterExplainer(
                id: descriptor.id,
                title: descriptor.title,
                summary: summary,
                dominantLabel: dominantLabel(for: summary),
                reviewImpact: makeReviewImpact(rows: rows),
                topDrivers: topDrivers(in: rows),
                exemplars: topExemplars(in: rows)
            )
        }

        guard !clusters.isEmpty else { return nil }

        let scopedRows = filteredGroups.flatMap { descriptor in
            grouped[descriptor.id] ?? []
        }
        let scopeSummary: String
        if let focusedClusterID,
           let cluster = clusters.first(where: { $0.id == focusedClusterID }) {
            scopeSummary = "\(wordZText("聚焦主题", "Focused Topic", mode: languageMode)): \(cluster.title)"
        } else {
            scopeSummary = "\(wordZText("主题范围", "Topic Scope", mode: languageMode)): \(clusters.map(\.title).joined(separator: " · "))"
        }

        return TopicsSentimentExplainer(
            scopeSummary: scopeSummary,
            overallSummary: makeSummary(
                id: "topics",
                title: wordZText("Topics x Sentiment", "Topics x Sentiment", mode: languageMode),
                rows: scopedRows
            ),
            clusters: clusters,
            overallReviewImpact: makeReviewImpact(rows: scopedRows)
        )
    }

    static func makeSummary(
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

    static func makeReviewImpact(rows: [SentimentEffectiveRow]) -> SentimentReviewImpactSummary {
        SentimentReviewImpactSummary(
            reviewedCount: rows.filter { $0.reviewStatus != .unreviewed }.count,
            confirmedRawCount: rows.filter { $0.reviewStatus == .confirmed }.count,
            overriddenCount: rows.filter { $0.reviewStatus == .overridden }.count,
            changedCount: rows.filter { $0.rawLabel != $0.effectiveLabel }.count,
            rawPositiveCount: rows.filter { $0.rawLabel == .positive }.count,
            rawNeutralCount: rows.filter { $0.rawLabel == .neutral }.count,
            rawNegativeCount: rows.filter { $0.rawLabel == .negative }.count,
            effectivePositiveCount: rows.filter { $0.effectiveLabel == .positive }.count,
            effectiveNeutralCount: rows.filter { $0.effectiveLabel == .neutral }.count,
            effectiveNegativeCount: rows.filter { $0.effectiveLabel == .negative }.count
        )
    }

    static func topDrivers(
        in rows: [SentimentEffectiveRow],
        limit: Int = 5
    ) -> [SentimentDriverCueSummary] {
        var aggregated: [String: (cue: String, direction: SentimentLabel, weight: Double, count: Int, tag: String)] = [:]

        for row in rows {
            let rawRow = row.rawRow
            if !rawRow.diagnostics.ruleTraces.isEmpty {
                for trace in rawRow.diagnostics.ruleTraces {
                    guard trace.adjustedScore != 0 else { continue }
                    let direction: SentimentLabel = trace.adjustedScore > 0 ? .positive : .negative
                    let cue = normalizedCue(trace.cueLemma ?? trace.cueSurface)
                    let primaryTag = trace.appliedSteps.first?.tag ?? trace.cueCategory.rawValue
                    let key = "\(direction.rawValue)::\(cue)::\(primaryTag)"
                    var entry = aggregated[key] ?? (cue, direction, 0, 0, primaryTag)
                    entry.weight += abs(trace.adjustedScore)
                    entry.count += 1
                    aggregated[key] = entry
                }
                continue
            }

            for hit in rawRow.evidence {
                guard hit.adjustedScore != 0 else { continue }
                let direction: SentimentLabel = hit.adjustedScore > 0 ? .positive : .negative
                let cue = normalizedCue(hit.lemma ?? hit.surface)
                let primaryTag = hit.ruleTags.first ?? "evidence"
                let key = "\(direction.rawValue)::\(cue)::\(primaryTag)"
                var entry = aggregated[key] ?? (cue, direction, 0, 0, primaryTag)
                entry.weight += abs(hit.adjustedScore)
                entry.count += 1
                aggregated[key] = entry
            }
        }

        return aggregated.values
            .sorted { lhs, rhs in
                if lhs.weight == rhs.weight {
                    return lhs.cue.localizedCaseInsensitiveCompare(rhs.cue) == .orderedAscending
                }
                return lhs.weight > rhs.weight
            }
            .prefix(limit)
            .map { entry in
                SentimentDriverCueSummary(
                    id: "\(entry.direction.rawValue)::\(entry.cue)::\(entry.tag)",
                    cue: entry.cue,
                    direction: entry.direction,
                    totalWeight: entry.weight,
                    occurrenceCount: entry.count,
                    primaryRuleTag: entry.tag
                )
            }
    }

    static func topExemplars(
        in rows: [SentimentEffectiveRow],
        limit: Int = 3
    ) -> [SentimentExemplarRowSummary] {
        rows.sorted { lhs, rhs in
            let lhsRank = reviewStatusRank(lhs.reviewStatus)
            let rhsRank = reviewStatusRank(rhs.reviewStatus)
            if lhsRank == rhsRank {
                let lhsNet = abs(lhs.rawRow.netScore)
                let rhsNet = abs(rhs.rawRow.netScore)
                if lhsNet == rhsNet {
                    return lhs.rawRow.text.localizedCaseInsensitiveCompare(rhs.rawRow.text) == .orderedAscending
                }
                return lhsNet > rhsNet
            }
            return lhsRank < rhsRank
        }
        .prefix(limit)
        .map { row in
            SentimentExemplarRowSummary(
                id: row.id,
                text: row.rawRow.text,
                sourceTitle: row.rawRow.sourceTitle,
                rawLabel: row.rawLabel,
                effectiveLabel: row.effectiveLabel,
                reviewStatus: row.reviewStatus,
                groupID: row.rawRow.groupID,
                groupTitle: row.rawRow.groupTitle,
                sourceID: row.rawRow.sourceID,
                sentenceID: row.rawRow.sentenceID,
                tokenIndex: row.rawRow.tokenIndex
            )
        }
    }

    static func dominantLabel(for summary: SentimentAggregateSummary) -> SentimentLabel {
        [
            (SentimentLabel.positive, summary.positiveCount),
            (SentimentLabel.neutral, summary.neutralCount),
            (SentimentLabel.negative, summary.negativeCount)
        ]
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.rawValue < rhs.0.rawValue
            }
            return lhs.1 > rhs.1
        }
        .first?.0 ?? .neutral
    }

    private static func rows(
        in groupID: String,
        from rows: [SentimentEffectiveRow]
    ) -> [SentimentEffectiveRow] {
        rows.filter { $0.rawRow.groupID == groupID }
    }

    private static func reviewStatusRank(_ status: SentimentReviewStatus) -> Int {
        switch status {
        case .overridden:
            return 0
        case .confirmed:
            return 1
        case .unreviewed:
            return 2
        }
    }

    private static func normalizedCue(_ cue: String) -> String {
        cue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func orderedGroupDescriptors(
        from texts: [SentimentInputText],
        fallbackRows: [SentimentEffectiveRow],
        languageMode: AppLanguageMode
    ) -> [(id: String, title: String)] {
        var seen: Set<String> = []
        var descriptors: [(String, String)] = []

        for text in texts {
            let groupID = text.groupID ?? text.groupTitle ?? wordZText("未分组", "Ungrouped", mode: languageMode)
            guard seen.insert(groupID).inserted else { continue }
            descriptors.append((groupID, text.groupTitle ?? text.groupID ?? groupID))
        }

        if !descriptors.isEmpty {
            return descriptors
        }

        for row in fallbackRows {
            let groupID = row.rawRow.groupID ?? row.rawRow.groupTitle ?? wordZText("未分组", "Ungrouped", mode: languageMode)
            guard seen.insert(groupID).inserted else { continue }
            descriptors.append((groupID, row.rawRow.groupTitle ?? row.rawRow.groupID ?? groupID))
        }
        return descriptors
    }
}
