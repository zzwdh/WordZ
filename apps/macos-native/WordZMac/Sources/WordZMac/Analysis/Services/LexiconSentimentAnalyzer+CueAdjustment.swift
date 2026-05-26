import Foundation

extension LexiconSentimentAnalyzer {
    func adjustSentimentMatch(
        _ match: SentimentPhraseMatch,
        in unit: SentimentScoringUnit,
        matches: [SentimentPhraseMatch],
        clauses: [SentimentClauseSegment],
        resolvedTokens: [String],
        normalizedTokens: [String],
        tokenRanges: [Range<String.Index>],
        quoteSpans: [Range<String.Index>],
        neutralShieldReason: String?,
        bangCount: Int,
        quoteDiscountEnabled: Bool,
        neutralShieldStrength: Double,
        quoteDiscountMultiplier: Double,
        reportingDiscountMultiplier: Double
    ) -> AdjustedSentimentEvidence {
        let clause = clause(for: match, clauses: clauses)
        let cueContext = cueContext(
            for: match,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens,
            tokenRanges: tokenRanges,
            quoteSpans: quoteSpans
        )
        var adjustedScore = match.entry.score * clause.weight
        var ruleTags: [String] = ["lexicon", match.entry.category.rawValue]
        var traceSteps: [SentimentRuleTraceStep] = [
            SentimentRuleTraceStep(
                tag: "cueMatched",
                note: match.entry.term,
                multiplier: nil
            )
        ]
        var reviewFlags: Set<SentimentReviewFlag> = []

        if clause.weight != 1.0 {
            let contrastTag = clause.weight > 1.0 ? "postContrast" : "preContrast"
            ruleTags.append(contrastTag)
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: contrastTag,
                    note: clause.weight > 1.0 ? "post-contrast clause reweighted" : "pre-contrast clause reweighted",
                    multiplier: clause.weight
                )
            )
        }

        if let intensity = precedingSentimentMultiplier(
            at: match.tokenIndex,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens,
            matches: matches
        ) {
            adjustedScore *= intensity.multiplier
            ruleTags.append(intensity.multiplier >= 1 ? "intensified" : "downtoned")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: intensity.multiplier >= 1 ? "intensified" : "downtoned",
                    note: intensity.trigger,
                    multiplier: intensity.multiplier
                )
            )
        }

        if let negator = negationCue(
            before: match.tokenIndex,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens
        ) {
            if adjustedScore >= 0 {
                adjustedScore = -abs(adjustedScore) * 0.8
            } else {
                adjustedScore = abs(adjustedScore) * 0.6
            }
            ruleTags.append("negated")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "negated",
                    note: negator,
                    multiplier: adjustedScore.sign == .minus ? -0.8 : 0.6
                )
            )
        }

        if match.entry.category == .weakEvaluative {
            adjustedScore *= 0.85
            ruleTags.append("weakCue")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "weakCue",
                    note: "weak evaluative cue",
                    multiplier: 0.85
                )
            )
        }

        if bangCount > 0, unit.tokens.count <= 25 {
            let multiplier = min(1.3, 1.0 + (0.1 * Double(bangCount)))
            adjustedScore *= multiplier
            ruleTags.append("exclamation")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "exclamation",
                    note: "sentence punctuation emphasis",
                    multiplier: multiplier
                )
            )
        }

        if quoteDiscountEnabled, cueContext.insideQuotes {
            adjustedScore *= quoteDiscountMultiplier
            ruleTags.append("quotedEvidence")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "quotedEvidence",
                    note: "quoted cue discounted",
                    multiplier: quoteDiscountMultiplier
                )
            )
            reviewFlags.insert(.quoted)
        }

        if quoteDiscountEnabled, cueContext.isReportedSpeech {
            adjustedScore *= reportingDiscountMultiplier
            ruleTags.append("reportedSpeech")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "reportedSpeech",
                    note: cueContext.reportingVerb.map { "attributed via \($0)" } ?? "reported speech discounted",
                    multiplier: reportingDiscountMultiplier
                )
            )
            reviewFlags.insert(.reported)
        }

        var shieldReason = neutralShieldReason
        if match.entry.category == .academicCaution || lexicon.hedges.contains(match.surface.lowercased()) {
            adjustedScore *= neutralShieldStrength
            ruleTags.append("neutralityShielded")
            traceSteps.append(
                SentimentRuleTraceStep(
                    tag: "neutralityShielded",
                    note: shieldReason ?? "academic hedge or cautious framing",
                    multiplier: neutralShieldStrength
                )
            )
            shieldReason = shieldReason ?? "academic hedge"
            reviewFlags.insert(.shielded)
        }

        let hit = SentimentEvidenceHit(
            id: "\(unit.id)::\(match.tokenIndex)",
            surface: match.surface,
            lemma: match.lemma?.isEmpty == false ? match.lemma : nil,
            baseScore: match.entry.score,
            adjustedScore: adjustedScore,
            ruleTags: ruleTags,
            tokenIndex: match.tokenIndex,
            tokenLength: match.tokenLength
        )

        let trace = SentimentRuleTrace(
            id: "\(unit.id)::trace::\(match.tokenIndex)",
            cueSurface: match.surface,
            cueLemma: match.lemma?.isEmpty == false ? match.lemma : nil,
            cueCategory: match.entry.category,
            packID: match.entry.packID,
            scopeStart: max(0, match.tokenIndex - 3),
            scopeEnd: min(unit.tokens.count - 1, match.tokenIndex + max(match.tokenLength, 2)),
            clauseIndex: clause.index,
            clauseWeight: clause.weight,
            baseScore: match.entry.score,
            adjustedScore: adjustedScore,
            appliedSteps: traceSteps,
            neutralShieldReason: shieldReason
        )

        return AdjustedSentimentEvidence(
            hit: hit,
            trace: trace,
            reviewFlags: Array(reviewFlags)
        )
    }

    func clause(
        for match: SentimentPhraseMatch,
        clauses: [SentimentClauseSegment]
    ) -> SentimentClauseSegment {
        clauses.first(where: { match.tokenIndex >= $0.startTokenIndex && match.tokenIndex <= $0.endTokenIndex })
            ?? SentimentClauseSegment(index: 0, startTokenIndex: 0, endTokenIndex: max(match.tokenIndex, 0), weight: 1.0)
    }

    func weightedClauses(
        in unit: SentimentScoringUnit,
        resolvedTokens: [String],
        normalizedTokens: [String]
    ) -> [SentimentClauseSegment] {
        var clauses = scopeSegmenter.segment(tokens: unit.tokens, resolvedTokens: resolvedTokens, lexicon: lexicon)
        guard let firstContrastiveIndex = resolvedTokens.firstIndex(where: lexicon.contrastives.contains)
            ?? normalizedTokens.firstIndex(where: lexicon.contrastives.contains) else {
            return clauses
        }

        clauses = clauses.map { clause in
            let weight: Double
            if clause.endTokenIndex < firstContrastiveIndex {
                weight = 0.75
            } else if clause.startTokenIndex > firstContrastiveIndex {
                weight = 1.25
            } else {
                weight = 1.0
            }
            return SentimentClauseSegment(
                index: clause.index,
                startTokenIndex: clause.startTokenIndex,
                endTokenIndex: clause.endTokenIndex,
                weight: weight
            )
        }
        return clauses
    }

    func negationCue(
        before tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String]
    ) -> String? {
        guard tokenIndex > 0 else { return nil }
        let start = max(0, tokenIndex - 4)
        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            if lexicon.contrastives.contains(resolved) || lexicon.contrastives.contains(normalized) {
                return nil
            }
            if lexicon.negators.contains(resolved) || lexicon.negators.contains(normalized) {
                return resolved
            }
            if candidateIndex > 0 {
                let bigramResolved = "\(resolvedTokens[candidateIndex - 1]) \(resolved)"
                let bigramNormalized = "\(normalizedTokens[candidateIndex - 1]) \(normalized)"
                if ["fail to", "lack of"].contains(bigramResolved) || ["fail to", "lack of"].contains(bigramNormalized) {
                    return bigramResolved
                }
            }
        }
        return nil
    }

    func precedingSentimentMultiplier(
        at tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String],
        matches: [SentimentPhraseMatch]
    ) -> (trigger: String, multiplier: Double)? {
        guard tokenIndex > 0 else { return nil }
        let start = max(0, tokenIndex - 2)
        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            if lexicon.contrastives.contains(resolved) || lexicon.contrastives.contains(normalized) {
                return nil
            }
            let hasEarlierCueBetween = matches.contains { match in
                match.tokenIndex > candidateIndex && match.tokenIndex < tokenIndex
            }
            if hasEarlierCueBetween {
                return nil
            }
            if let multiplier = lexicon.intensifiers[resolved] ?? lexicon.intensifiers[normalized] {
                return (resolved, multiplier)
            }
        }
        return nil
    }

    func neutralShieldReason(
        in unit: SentimentScoringUnit,
        resolvedTokens: [String]
    ) -> String? {
        let joined = resolvedTokens.joined(separator: " ")
        for (cue, reason) in lexicon.neutralShields {
            if joined.contains(cue) || unit.text.localizedCaseInsensitiveContains(cue) {
                return reason
            }
        }
        if resolvedTokens.contains(where: lexicon.hedges.contains) {
            return "hedged framing"
        }
        return nil
    }


    func rebuildEvidence(
        _ evidence: AdjustedSentimentEvidence,
        adjustedScore: Double,
        tag: String,
        note: String,
        multiplier: Double,
        addReviewFlag: SentimentReviewFlag
    ) -> AdjustedSentimentEvidence {
        let hit = SentimentEvidenceHit(
            id: evidence.hit.id,
            surface: evidence.hit.surface,
            lemma: evidence.hit.lemma,
            baseScore: evidence.hit.baseScore,
            adjustedScore: adjustedScore,
            ruleTags: evidence.hit.ruleTags + [tag],
            tokenIndex: evidence.hit.tokenIndex,
            tokenLength: evidence.hit.tokenLength
        )
        let trace = SentimentRuleTrace(
            id: evidence.trace.id,
            cueSurface: evidence.trace.cueSurface,
            cueLemma: evidence.trace.cueLemma,
            cueCategory: evidence.trace.cueCategory,
            packID: evidence.trace.packID,
            scopeStart: evidence.trace.scopeStart,
            scopeEnd: evidence.trace.scopeEnd,
            clauseIndex: evidence.trace.clauseIndex,
            clauseWeight: evidence.trace.clauseWeight,
            baseScore: evidence.trace.baseScore,
            adjustedScore: adjustedScore,
            appliedSteps: evidence.trace.appliedSteps + [
                SentimentRuleTraceStep(tag: tag, note: note, multiplier: multiplier)
            ],
            neutralShieldReason: note
        )
        return AdjustedSentimentEvidence(
            hit: hit,
            trace: trace,
            reviewFlags: Array(Set(evidence.reviewFlags + [addReviewFlag]))
        )
    }

}
