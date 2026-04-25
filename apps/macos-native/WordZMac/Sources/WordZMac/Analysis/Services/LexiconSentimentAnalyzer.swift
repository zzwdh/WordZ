import Foundation

private struct SentimentScoringUnit {
    let id: String
    let sourceID: String?
    let sourceTitle: String
    let groupID: String?
    let groupTitle: String?
    let text: String
    let sentenceID: Int?
    let tokenIndex: Int?
    let tokens: [ParsedToken]
}

private struct SentimentPhraseMatch {
    let entry: SentimentLexiconEntry
    let tokenIndex: Int
    let tokenLength: Int
    let surface: String
    let lemma: String?
}

private struct AdjustedSentimentEvidence {
    let hit: SentimentEvidenceHit
    let trace: SentimentRuleTrace
    let reviewFlags: [SentimentReviewFlag]
}

private struct SentimentCueContext {
    let insideQuotes: Bool
    let reportingVerb: String?
    let isReportedSpeech: Bool
}

private struct SentimentScoredRow {
    let positivityScore: Double
    let negativityScore: Double
    let neutralityScore: Double
    let finalLabel: SentimentLabel
    let netScore: Double
    let evidence: [SentimentEvidenceHit]
    let evidenceCount: Int
    let mixedEvidence: Bool
    let positiveEvidence: Double
    let negativeEvidence: Double
    let diagnostics: SentimentRowDiagnostics
}

final class LexiconSentimentAnalyzer: SentimentAnalyzing {
    private let indexDocument: (String, DocumentCacheKey?) -> ParsedDocumentIndex
    private let lexicon: SentimentLexiconStore
    private let rulePackResolver: SentimentRulePackResolver
    private let scopeSegmenter: SentimentScopeSegmenter
    private let calibrationProfileProvider: SentimentCalibrationProfileProviding

    init(
        indexDocument: @escaping (String, DocumentCacheKey?) -> ParsedDocumentIndex,
        lexicon: SentimentLexiconStore = .shared,
        rulePackResolver: SentimentRulePackResolver? = nil,
        scopeSegmenter: SentimentScopeSegmenter = SentimentScopeSegmenter(),
        calibrationProfileProvider: SentimentCalibrationProfileProviding = DefaultSentimentCalibrationProfileProvider()
    ) {
        self.indexDocument = indexDocument
        self.lexicon = lexicon
        self.rulePackResolver = rulePackResolver ?? SentimentRulePackResolver(lexicon: lexicon)
        self.scopeSegmenter = scopeSegmenter
        self.calibrationProfileProvider = calibrationProfileProvider
    }

    func analyze(_ request: SentimentRunRequest) throws -> SentimentRunResult {
        if let loadError = lexicon.loadError {
            throw loadError
        }

        let resolvedPack = rulePackResolver.resolve(for: request)
        let calibrationProfile = calibrationProfileProvider.calibrationProfile(for: request)
        let thresholds = effectiveThresholds(for: request, calibrationProfile: calibrationProfile)

        let rows: [SentimentRowResult]
        switch request.unit {
        case .document:
            rows = request.texts.map {
                scoreDocument(
                    $0,
                    request: request,
                    resolvedPack: resolvedPack,
                    thresholds: thresholds,
                    calibrationProfile: calibrationProfile
                )
            }
        case .sentence:
            rows = buildSentenceUnits(request: request).map { unit in
                makeRow(
                    from: scoreUnit(
                        unit,
                        request: request,
                        resolvedPack: resolvedPack,
                        thresholds: thresholds,
                        calibrationProfile: calibrationProfile
                    ),
                    unit: unit
                )
            }
        case .concordanceLine, .sourceSentence:
            rows = buildConcordanceUnits(request: request).map { unit in
                makeRow(
                    from: scoreUnit(
                        unit,
                        request: request,
                        resolvedPack: resolvedPack,
                        thresholds: thresholds,
                        calibrationProfile: calibrationProfile
                    ),
                    unit: unit
                )
            }
        }

        return SentimentResultAggregation.makeRunResult(
            request: request,
            backendKind: .lexicon,
            backendRevision: lexicon.backendRevision,
            resourceRevision: lexicon.resourceRevision,
            supportsEvidenceHits: true,
            rows: rows,
            lexiconVersion: lexicon.version,
            activeRuleProfileRevision: request.ruleProfile.revision,
            activePackIDs: resolvedPack.activePackIDs,
            calibrationProfileRevision: calibrationProfile.revision,
            userLexiconBundleIDs: request.userLexiconBundleIDs
        )
    }

    private func scoreDocument(
        _ input: SentimentInputText,
        request: SentimentRunRequest,
        resolvedPack: SentimentResolvedRulePack,
        thresholds: SentimentThresholds,
        calibrationProfile: SentimentCalibrationProfile
    ) -> SentimentRowResult {
        let text = resolveText(for: input, request: request)
        let indexed = indexDocument(text, DocumentCacheKey(text: text))
        let sentenceUnits = indexed.document.sentences.map { sentence in
            SentimentScoringUnit(
                id: "\(input.id)::sentence::\(sentence.sentenceId)",
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: sentence.text,
                sentenceID: sentence.sentenceId,
                tokenIndex: sentence.tokens.first?.tokenIndex,
                tokens: sentence.tokens
            )
        }

        let scoredSentences: [SentimentScoredRow]
        if sentenceUnits.isEmpty {
            let fallbackUnit = SentimentScoringUnit(
                id: input.id,
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: text,
                sentenceID: input.sentenceID,
                tokenIndex: input.tokenIndex,
                tokens: indexed.document.tokens
            )
            scoredSentences = [
                scoreUnit(
                    fallbackUnit,
                    request: request,
                    resolvedPack: resolvedPack,
                    thresholds: thresholds,
                    calibrationProfile: calibrationProfile
                )
            ]
        } else {
            scoredSentences = sentenceUnits.map {
                scoreUnit(
                    $0,
                    request: request,
                    resolvedPack: resolvedPack,
                    thresholds: thresholds,
                    calibrationProfile: calibrationProfile
                )
            }
        }

        let sentenceCount = Double(max(scoredSentences.count, 1))
        let positiveMean = scoredSentences.reduce(0.0) { $0 + $1.positivityScore } / sentenceCount
        let negativeMean = scoredSentences.reduce(0.0) { $0 + $1.negativityScore } / sentenceCount
        let neutralMean = scoredSentences.reduce(0.0) { $0 + $1.neutralityScore } / sentenceCount
        let netMean = scoredSentences.reduce(0.0) { $0 + $1.netScore } / sentenceCount
        let averageEvidence = scoredSentences.reduce(0.0) {
            $0 + $1.positiveEvidence + $1.negativeEvidence
        } / sentenceCount
        let evidence = scoredSentences.flatMap(\.evidence)
        let allRuleTraces = scoredSentences.flatMap { $0.diagnostics.ruleTraces }
        let allReviewFlags = Set(scoredSentences.flatMap { $0.diagnostics.reviewFlags })
        let mixedEvidence = scoredSentences.contains(where: \.mixedEvidence)
            || (positiveMean > 0.2 && negativeMean > 0.2 && abs(netMean) < thresholds.decisionThreshold)

        let finalLabel: SentimentLabel
        if evidence.isEmpty
            || averageEvidence < thresholds.minimumEvidence
            || abs(netMean) < thresholds.decisionThreshold
            || mixedEvidence {
            finalLabel = .neutral
        } else if positiveMean >= negativeMean {
            finalLabel = .positive
        } else {
            finalLabel = .negative
        }

        var scopeNotes = Array(Set(scoredSentences.flatMap { $0.diagnostics.scopeNotes })).sorted()
        if mixedEvidence {
            scopeNotes.append("mixedEvidence")
        }

        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: mixedEvidence,
            ruleSummary: "Document aggregated from \(scoredSentences.count) sentences",
            scopeNotes: scopeNotes,
            confidence: nil,
            topMargin: nil,
            subunitCount: scoredSentences.count,
            truncated: false,
            aggregatedFrom: .sentenceMean,
            modelRevision: nil,
            ruleTraces: allRuleTraces,
            reviewFlags: Array(allReviewFlags),
            activeRuleProfileID: request.ruleProfile.id,
            activePackIDs: resolvedPack.activePackIDs,
            calibrationProfileRevision: calibrationProfile.revision,
            inferencePath: .lexicon
        )

        return SentimentRowResult(
            id: input.id,
            sourceID: input.sourceID,
            sourceTitle: input.sourceTitle,
            groupID: input.groupID,
            groupTitle: input.groupTitle,
            text: text,
            positivityScore: positiveMean,
            negativityScore: negativeMean,
            neutralityScore: neutralMean,
            finalLabel: finalLabel,
            netScore: netMean,
            evidence: evidence,
            evidenceCount: evidence.count,
            mixedEvidence: mixedEvidence,
            diagnostics: diagnostics,
            sentenceID: input.sentenceID,
            tokenIndex: input.tokenIndex
        )
    }

    private func buildSentenceUnits(request: SentimentRunRequest) -> [SentimentScoringUnit] {
        request.texts.flatMap { input in
            let text = resolveText(for: input, request: request)
            let indexed = indexDocument(text, DocumentCacheKey(text: text))
            return indexed.document.sentences.map { sentence in
                SentimentScoringUnit(
                    id: "\(input.id)::sentence::\(sentence.sentenceId)",
                    sourceID: input.sourceID,
                    sourceTitle: input.sourceTitle,
                    groupID: input.groupID,
                    groupTitle: input.groupTitle,
                    text: sentence.text,
                    sentenceID: sentence.sentenceId,
                    tokenIndex: sentence.tokens.first?.tokenIndex,
                    tokens: sentence.tokens
                )
            }
        }
    }

    private func buildConcordanceUnits(request: SentimentRunRequest) -> [SentimentScoringUnit] {
        request.texts.map { input in
            let text = resolveText(for: input, request: request)
            let indexed = indexDocument(text, DocumentCacheKey(text: text))
            let tokens = indexed.document.sentences.first?.tokens ?? indexed.document.tokens
            return SentimentScoringUnit(
                id: input.id,
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: text,
                sentenceID: input.sentenceID,
                tokenIndex: input.tokenIndex,
                tokens: tokens
            )
        }
    }

    private func scoreUnit(
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

    private func makeRow(
        from scored: SentimentScoredRow,
        unit: SentimentScoringUnit
    ) -> SentimentRowResult {
        SentimentRowResult(
            id: unit.id,
            sourceID: unit.sourceID,
            sourceTitle: unit.sourceTitle,
            groupID: unit.groupID,
            groupTitle: unit.groupTitle,
            text: unit.text,
            positivityScore: scored.positivityScore,
            negativityScore: scored.negativityScore,
            neutralityScore: scored.neutralityScore,
            finalLabel: scored.finalLabel,
            netScore: scored.netScore,
            evidence: scored.evidence,
            evidenceCount: scored.evidenceCount,
            mixedEvidence: scored.mixedEvidence,
            diagnostics: scored.diagnostics,
            sentenceID: unit.sentenceID,
            tokenIndex: unit.tokenIndex
        )
    }

    private func sentimentMatches(
        in tokens: [ParsedToken],
        resolvedPack: SentimentResolvedRulePack
    ) -> [SentimentPhraseMatch] {
        let lemmaTokens = tokens.map {
            TokenLemmaStrategy.lemmaPreferred.resolvedToken(
                normalized: $0.normalized,
                annotations: $0.annotations
            )
        }

        var matches: [SentimentPhraseMatch] = []
        var index = 0

        while index < tokens.count {
            var matchedPhrase: SentimentPhraseMatch?
            let remaining = tokens.count - index
            let maxLength = min(resolvedPack.maxEntryLength, remaining)

            if maxLength > 0 {
                for length in stride(from: maxLength, through: 1, by: -1) {
                    guard let entries = resolvedPack.entriesByLength[length] else { continue }
                    let normalizedSlice = Array(tokens[index..<(index + length)].map(\.normalized))
                    let lemmaSlice = Array(lemmaTokens[index..<(index + length)])
                    if let entry = entries.first(where: {
                        switch $0.matchMode {
                        case .lemma:
                            return $0.tokens == lemmaSlice
                        case .surface:
                            return $0.tokens == normalizedSlice
                        case .either:
                            return $0.tokens == lemmaSlice || $0.tokens == normalizedSlice
                        }
                    }) {
                        matchedPhrase = SentimentPhraseMatch(
                            entry: entry,
                            tokenIndex: index,
                            tokenLength: length,
                            surface: tokens[index..<(index + length)].map(\.original).joined(separator: " "),
                            lemma: lemmaSlice.joined(separator: " ")
                        )
                        break
                    }
                }
            }

            if let matchedPhrase {
                matches.append(matchedPhrase)
                index += matchedPhrase.tokenLength
            } else {
                index += 1
            }
        }

        return matches
    }

    private func adjustSentimentMatch(
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

    private func clause(
        for match: SentimentPhraseMatch,
        clauses: [SentimentClauseSegment]
    ) -> SentimentClauseSegment {
        clauses.first(where: { match.tokenIndex >= $0.startTokenIndex && match.tokenIndex <= $0.endTokenIndex })
            ?? SentimentClauseSegment(index: 0, startTokenIndex: 0, endTokenIndex: max(match.tokenIndex, 0), weight: 1.0)
    }

    private func weightedClauses(
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

    private func negationCue(
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

    private func precedingSentimentMultiplier(
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

    private func neutralShieldReason(
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

    private func cueContext(
        for match: SentimentPhraseMatch,
        resolvedTokens: [String],
        normalizedTokens: [String],
        tokenRanges: [Range<String.Index>],
        quoteSpans: [Range<String.Index>]
    ) -> SentimentCueContext {
        let insideQuotes = cueCharacterRange(for: match, tokenRanges: tokenRanges)
            .map { isInsideQuotes($0, quoteSpans: quoteSpans) } ?? false
        let reportingVerb = reportingVerb(
            near: match.tokenIndex,
            resolvedTokens: resolvedTokens,
            normalizedTokens: normalizedTokens,
            allowFollowingVerb: insideQuotes
        )
        let isReportedSpeech: Bool
        if insideQuotes {
            isReportedSpeech = reportingVerb != nil
        } else {
            isReportedSpeech = reportingVerb != nil && reportingConnectorExists(
                before: match.tokenIndex,
                resolvedTokens: resolvedTokens,
                normalizedTokens: normalizedTokens
            )
        }
        return SentimentCueContext(
            insideQuotes: insideQuotes,
            reportingVerb: reportingVerb,
            isReportedSpeech: isReportedSpeech
        )
    }

    private func tokenRanges(
        in text: String,
        tokens: [ParsedToken]
    ) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStart = text.startIndex

        for token in tokens {
            guard searchStart <= text.endIndex,
                  let range = text.range(of: token.original, range: searchStart..<text.endIndex) else {
                continue
            }
            ranges.append(range)
            searchStart = range.upperBound
        }
        return ranges
    }

    private func quoteSpans(in text: String) -> [Range<String.Index>] {
        var spans: [Range<String.Index>] = []
        var openingQuote: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            if character == "\"" || character == "“" || character == "”" {
                if let existingOpeningQuote = openingQuote {
                    let start = text.index(after: existingOpeningQuote)
                    if start <= index {
                        spans.append(start..<index)
                    }
                    self.consumeTrailingQuotePunctuation(in: text, from: &index)
                    openingQuote = nil
                } else {
                    openingQuote = index
                }
            }
            index = text.index(after: index)
        }

        return spans
    }

    private func consumeTrailingQuotePunctuation(
        in text: String,
        from index: inout String.Index
    ) {
        while index < text.endIndex {
            let nextIndex = text.index(after: index)
            guard nextIndex < text.endIndex else { return }
            let character = text[nextIndex]
            if character == "," || character == "." || character == ";" || character == ":" {
                index = nextIndex
                continue
            }
            return
        }
    }

    private func cueCharacterRange(
        for match: SentimentPhraseMatch,
        tokenRanges: [Range<String.Index>]
    ) -> Range<String.Index>? {
        let startIndex = match.tokenIndex
        let endIndex = match.tokenIndex + match.tokenLength - 1
        guard tokenRanges.indices.contains(startIndex),
              tokenRanges.indices.contains(endIndex) else {
            return nil
        }
        return tokenRanges[startIndex].lowerBound..<tokenRanges[endIndex].upperBound
    }

    private func isInsideQuotes(
        _ cueRange: Range<String.Index>,
        quoteSpans: [Range<String.Index>]
    ) -> Bool {
        quoteSpans.contains { span in
            span.lowerBound <= cueRange.lowerBound && span.upperBound >= cueRange.upperBound
        }
    }

    private func reportingVerb(
        near tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String],
        allowFollowingVerb: Bool
    ) -> String? {
        guard !resolvedTokens.isEmpty else { return nil }
        let start = max(0, tokenIndex - 4)
        let end = min(resolvedTokens.count - 1, allowFollowingVerb ? tokenIndex + 4 : tokenIndex)

        if tokenIndex > 0 {
            for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
                let resolved = resolvedTokens[candidateIndex]
                let normalized = normalizedTokens[candidateIndex]
                if lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) {
                    return resolved
                }
            }
        }

        guard allowFollowingVerb, tokenIndex + 1 <= end else { return nil }
        for candidateIndex in (tokenIndex + 1)...end {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            if lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) {
                return resolved
            }
        }

        return nil
    }

    private func reportingConnectorExists(
        before tokenIndex: Int,
        resolvedTokens: [String],
        normalizedTokens: [String]
    ) -> Bool {
        guard tokenIndex > 0 else { return false }
        let start = max(0, tokenIndex - 4)
        let connectors: Set<String> = ["as", "that", "to", "be", "being", "is", "are", "was", "were"]

        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            let resolved = resolvedTokens[candidateIndex]
            let normalized = normalizedTokens[candidateIndex]
            guard lexicon.reportingVerbs.contains(resolved) || lexicon.reportingVerbs.contains(normalized) else {
                continue
            }
            let betweenResolved = resolvedTokens[(candidateIndex + 1)..<tokenIndex]
            let betweenNormalized = normalizedTokens[(candidateIndex + 1)..<tokenIndex]
            return betweenResolved.contains(where: connectors.contains)
                || betweenNormalized.contains(where: connectors.contains)
        }

        return false
    }

    private func buildRuleSummary(
        evidenceCount: Int,
        mixedEvidence: Bool,
        ruleTraces: [SentimentRuleTrace]
    ) -> String {
        guard evidenceCount > 0 else { return "No strong lexical evidence" }
        let stepTags = ruleTraces
            .flatMap(\.appliedSteps)
            .map(\.tag)
            .filter { $0 != "cueMatched" }
            .uniquedPreservingOrder()
            .prefix(3)
            .joined(separator: ", ")
        if mixedEvidence {
            return stepTags.isEmpty
                ? "Mixed evidence across \(evidenceCount) cues"
                : "Mixed evidence across \(evidenceCount) cues (\(stepTags))"
        }
        return stepTags.isEmpty
            ? "\(evidenceCount) lexical cue(s)"
            : "\(evidenceCount) cue(s) with \(stepTags)"
    }

    private func effectiveThresholds(
        for request: SentimentRunRequest,
        calibrationProfile: SentimentCalibrationProfile
    ) -> SentimentThresholds {
        var thresholds = calibrationProfile.thresholds(overriding: request.thresholds)
        thresholds.neutralBias += calibrationProfile.domainBiasAdjustments[request.resolvedDomainPackID.rawValue] ?? 0
        return thresholds
    }

    private func rebuildEvidence(
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

    private func resolveText(
        for input: SentimentInputText,
        request: SentimentRunRequest
    ) -> String {
        guard request.unit == .concordanceLine || request.unit == .sourceSentence,
              request.contextBasis == .fullSentenceWhenAvailable,
              let documentText = input.documentText,
              let sentenceID = input.sentenceID else {
            return input.text
        }
        let indexed = indexDocument(documentText, DocumentCacheKey(text: documentText))
        return indexed.document.sentences.first(where: { $0.sentenceId == sentenceID })?.text ?? input.text
    }
}

private extension Array where Element == String {
    func uniquedPreservingOrder() -> [String] {
        var seen: Set<String> = []
        return filter { value in
            seen.insert(value).inserted
        }
    }
}
