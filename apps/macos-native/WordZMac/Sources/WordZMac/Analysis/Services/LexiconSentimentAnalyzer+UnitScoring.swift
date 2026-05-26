import Foundation

extension LexiconSentimentAnalyzer {
    func scoreUnit(
        _ unit: SentimentScoringUnit,
        request: SentimentRunRequest,
        resolvedPack: SentimentResolvedRulePack,
        thresholds: SentimentThresholds,
        calibrationProfile: SentimentCalibrationProfile
    ) -> SentimentScoredRow {
        let resolvedTokens = unit.tokens.map {
            TokenLemmaStrategy.lemmaPreferred.resolvedToken(
                normalized: $0.normalized,
                annotations: $0.annotations
            )
        }
        let normalizedTokens = unit.tokens.map(\.normalized)
        let clauses = weightedClauses(
            in: unit,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens
        )
        let matches = sentimentMatches(in: unit.tokens, resolvedPack: resolvedPack)
        let neutralShieldReason = neutralShieldReason(in: unit, resolvedTokens: resolvedTokens)
        let quoteDiscountEnabled = request.ruleProfile.quoteDiscountEnabled
        let tokenRanges = tokenRanges(in: unit.text, tokens: unit.tokens)
        let quoteSpans = quoteSpans(in: unit.text)
        let bangCount = unit.text.filter { $0 == "!" }.count

        var adjusted: [AdjustedSentimentEvidence] = matches.map {
            adjustSentimentMatch(
                $0,
                in: unit,
                matches: matches,
                clauses: clauses,
                resolvedTokens: resolvedTokens,
                normalizedTokens: normalizedTokens,
                tokenRanges: tokenRanges,
                quoteSpans: quoteSpans,
                neutralShieldReason: neutralShieldReason,
                bangCount: bangCount,
                quoteDiscountEnabled: quoteDiscountEnabled,
                neutralShieldStrength: request.ruleProfile.neutralShieldStrength,
                quoteDiscountMultiplier: request.ruleProfile.quoteDiscountMultiplier,
                reportingDiscountMultiplier: request.ruleProfile.reportingDiscountMultiplier
            )
        }

        let hasShieldedContext = neutralShieldReason != nil
            || adjusted.contains(where: { $0.trace.neutralShieldReason?.isEmpty == false })
        let hasStrongPolarCue = adjusted.contains {
            [.corePositive, .coreNegative, .newsEvaluative].contains($0.trace.cueCategory)
                && abs($0.hit.adjustedScore) >= 1.0
        }
        if hasShieldedContext && !hasStrongPolarCue {
            adjusted = adjusted.map { evidence in
                guard [.academicCaution, .weakEvaluative, .hedge].contains(evidence.trace.cueCategory) else {
                    return evidence
                }
                let dampenedScore = evidence.hit.adjustedScore * request.ruleProfile.neutralShieldStrength
                return rebuildEvidence(
                    evidence,
                    adjustedScore: dampenedScore,
                    tag: "neutralityShielded",
                    note: neutralShieldReason ?? "neutral shield",
                    multiplier: request.ruleProfile.neutralShieldStrength,
                    addReviewFlag: .shielded
                )
            }
        }

        let hits = adjusted.map(\.hit)
        let positiveEvidence = hits.reduce(0.0) { $0 + max($1.adjustedScore, 0) }
        let negativeEvidence = hits.reduce(0.0) { $0 + max(-$1.adjustedScore, 0) }
        let evidenceTotal = positiveEvidence + negativeEvidence
        let netScore = positiveEvidence - negativeEvidence
        let mixedEvidence = positiveEvidence > 0
            && negativeEvidence > 0
            && abs(netScore) < thresholds.decisionThreshold
        let shieldBonus = hasShieldedContext ? 0.25 : 0.0
        let neutralRaw = hits.isEmpty
            ? 2.0
            : max(0.2, thresholds.neutralBias + shieldBonus - abs(netScore))
        let total = max(positiveEvidence + negativeEvidence + neutralRaw, 0.0001)
        let finalLabel: SentimentLabel
        if hits.isEmpty || evidenceTotal < thresholds.minimumEvidence || abs(netScore) < thresholds.decisionThreshold || mixedEvidence {
            finalLabel = .neutral
        } else if netScore >= thresholds.decisionThreshold {
            finalLabel = .positive
        } else {
            finalLabel = .negative
        }

        var reviewFlags = Set(adjusted.flatMap(\.reviewFlags))
        if mixedEvidence {
            reviewFlags.insert(.mixedEvidence)
        }
        if abs(netScore) < thresholds.decisionThreshold + 0.15 {
            reviewFlags.insert(.lowMargin)
        }
        if hasShieldedContext {
            reviewFlags.insert(.shielded)
        }

        let scopeNotes = Array(Set(hits.flatMap(\.ruleTags) + [neutralShieldReason].compactMap { $0 })).sorted()
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: mixedEvidence,
            ruleSummary: buildRuleSummary(
                evidenceCount: hits.count,
                mixedEvidence: mixedEvidence,
                ruleTraces: adjusted.map(\.trace)
            ),
            scopeNotes: scopeNotes,
            confidence: nil,
            topMargin: nil,
            subunitCount: nil,
            truncated: false,
            aggregatedFrom: .direct,
            modelRevision: nil,
            ruleTraces: adjusted.map(\.trace),
            reviewFlags: Array(reviewFlags).sorted(by: { $0.rawValue < $1.rawValue }),
            activeRuleProfileID: request.ruleProfile.id,
            activePackIDs: resolvedPack.activePackIDs,
            calibrationProfileRevision: calibrationProfile.revision,
            inferencePath: .lexicon
        )

        return SentimentScoredRow(
            positivityScore: positiveEvidence / total,
            negativityScore: negativeEvidence / total,
            neutralityScore: neutralRaw / total,
            finalLabel: finalLabel,
            netScore: netScore,
            evidence: hits,
            evidenceCount: hits.count,
            mixedEvidence: mixedEvidence,
            positiveEvidence: positiveEvidence,
            negativeEvidence: negativeEvidence,
            diagnostics: diagnostics
        )
    }

}
