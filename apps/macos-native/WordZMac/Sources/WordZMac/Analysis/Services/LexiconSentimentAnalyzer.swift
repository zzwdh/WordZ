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

    init(
        indexDocument: @escaping (String, DocumentCacheKey?) -> ParsedDocumentIndex,
        lexicon: SentimentLexiconStore = .shared
    ) {
        self.indexDocument = indexDocument
        self.lexicon = lexicon
    }

    func analyze(_ request: SentimentRunRequest) throws -> SentimentRunResult {
        let rows: [SentimentRowResult]
        switch request.unit {
        case .document:
            rows = request.texts.map { scoreDocument($0, request: request) }
        case .sentence:
            rows = buildSentenceUnits(request: request).map { unit in
                makeRow(from: scoreUnit(unit, request: request), unit: unit)
            }
        case .concordanceLine:
            rows = buildConcordanceUnits(request: request).map { unit in
                makeRow(from: scoreUnit(unit, request: request), unit: unit)
            }
        }

        return SentimentResultAggregation.makeRunResult(
            request: request,
            backendKind: .lexicon,
            backendRevision: lexicon.backendRevision,
            resourceRevision: lexicon.resourceRevision,
            supportsEvidenceHits: true,
            rows: rows,
            lexiconVersion: lexicon.version
        )
    }

    private func scoreDocument(
        _ input: SentimentInputText,
        request: SentimentRunRequest
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
            scoredSentences = [scoreUnit(fallbackUnit, request: request)]
        } else {
            scoredSentences = sentenceUnits.map { scoreUnit($0, request: request) }
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
        let mixedEvidence = scoredSentences.contains(where: \.mixedEvidence)
            || (positiveMean > 0.2 && negativeMean > 0.2 && abs(netMean) < request.thresholds.decisionThreshold)
        let finalLabel: SentimentLabel
        if evidence.isEmpty || averageEvidence < request.thresholds.minimumEvidence || abs(netMean) < request.thresholds.decisionThreshold || mixedEvidence {
            finalLabel = .neutral
        } else if positiveMean >= negativeMean {
            finalLabel = .positive
        } else {
            finalLabel = .negative
        }

        let scopeNotes = Array(Set(scoredSentences.flatMap { $0.diagnostics.scopeNotes })).sorted()
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: mixedEvidence,
            ruleSummary: "Document aggregated from \(scoredSentences.count) sentences",
            scopeNotes: scopeNotes,
            confidence: nil,
            topMargin: nil,
            subunitCount: scoredSentences.count,
            truncated: false,
            aggregatedFrom: .sentenceMean,
            modelRevision: nil
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
        request: SentimentRunRequest
    ) -> SentimentScoredRow {
        let matches = sentimentMatches(in: unit.tokens)
        var adjustedHits = matches.map { adjustSentimentMatch($0, in: unit, matches: matches) }
        let hasAcademicShield = adjustedHits.contains {
            $0.ruleTags.contains(SentimentCueCategory.academicCaution.rawValue)
        } && !adjustedHits.contains {
            $0.ruleTags.contains(SentimentCueCategory.corePositive.rawValue)
                || $0.ruleTags.contains(SentimentCueCategory.coreNegative.rawValue)
        }
        if hasAcademicShield {
            adjustedHits = adjustedHits.map { hit in
                guard hit.ruleTags.contains(SentimentCueCategory.academicCaution.rawValue)
                    || hit.ruleTags.contains(SentimentCueCategory.weakEvaluative.rawValue) else {
                    return hit
                }
                return SentimentEvidenceHit(
                    id: hit.id,
                    surface: hit.surface,
                    lemma: hit.lemma,
                    baseScore: hit.baseScore,
                    adjustedScore: hit.adjustedScore * 0.65,
                    ruleTags: hit.ruleTags + ["neutralityShielded"],
                    tokenIndex: hit.tokenIndex,
                    tokenLength: hit.tokenLength
                )
            }
        }

        let positiveEvidence = adjustedHits.reduce(0.0) { $0 + max($1.adjustedScore, 0) }
        let negativeEvidence = adjustedHits.reduce(0.0) { $0 + max(-$1.adjustedScore, 0) }
        let evidenceTotal = positiveEvidence + negativeEvidence
        let netScore = positiveEvidence - negativeEvidence
        let mixedEvidence = positiveEvidence > 0
            && negativeEvidence > 0
            && abs(netScore) < request.thresholds.decisionThreshold
        let shieldBonus = hasAcademicShield ? 0.25 : 0.0
        let neutralRaw = adjustedHits.isEmpty
            ? 2.0
            : max(0.2, request.thresholds.neutralBias + shieldBonus - abs(netScore))
        let total = max(positiveEvidence + negativeEvidence + neutralRaw, 0.0001)
        let finalLabel: SentimentLabel
        if adjustedHits.isEmpty || evidenceTotal < request.thresholds.minimumEvidence || abs(netScore) < request.thresholds.decisionThreshold || mixedEvidence {
            finalLabel = .neutral
        } else if netScore >= request.thresholds.decisionThreshold {
            finalLabel = .positive
        } else {
            finalLabel = .negative
        }

        let scopeNotes = Array(Set(adjustedHits.flatMap(\.ruleTags))).sorted()
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: mixedEvidence,
            ruleSummary: buildRuleSummary(
                evidenceCount: adjustedHits.count,
                mixedEvidence: mixedEvidence,
                scopeNotes: scopeNotes
            ),
            scopeNotes: scopeNotes,
            confidence: nil,
            topMargin: nil,
            subunitCount: nil,
            truncated: false,
            aggregatedFrom: .direct,
            modelRevision: nil
        )

        return SentimentScoredRow(
            positivityScore: positiveEvidence / total,
            negativityScore: negativeEvidence / total,
            neutralityScore: neutralRaw / total,
            finalLabel: finalLabel,
            netScore: netScore,
            evidence: adjustedHits,
            evidenceCount: adjustedHits.count,
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

    private func sentimentMatches(in tokens: [ParsedToken]) -> [SentimentPhraseMatch] {
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
            let maxLength = min(lexicon.maxEntryLength, remaining)

            if maxLength > 0 {
                for length in stride(from: maxLength, through: 1, by: -1) {
                    guard let entries = lexicon.entriesByLength[length] else { continue }
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
        matches: [SentimentPhraseMatch]
    ) -> SentimentEvidenceHit {
        let resolvedTokens = unit.tokens.map {
            TokenLemmaStrategy.lemmaPreferred.resolvedToken(
                normalized: $0.normalized,
                annotations: $0.annotations
            )
        }
        let normalizedTokens = unit.tokens.map(\.normalized)
        let contrastiveIndexes = resolvedTokens.enumerated().compactMap { offset, value in
            lexicon.contrastives.contains(value) ? offset : nil
        }
        let lastContrastiveIndex = contrastiveIndexes.max()
        let reportingVerbPresent = resolvedTokens.contains(where: lexicon.reportingVerbs.contains)
            || normalizedTokens.contains(where: lexicon.reportingVerbs.contains)
        let hasQuoteMarks = unit.text.contains("\"")
            || unit.text.contains("“")
            || unit.text.contains("”")
            || unit.text.contains("'")
        let bangCount = unit.text.filter { $0 == "!" }.count

        var adjustedScore = match.entry.score
        var ruleTags: [String] = ["lexicon", match.entry.category.rawValue]

        if let multiplier = precedingSentimentMultiplier(
            at: match.tokenIndex,
            resolvedTokens: resolvedTokens,
            matches: matches
        ) {
            adjustedScore *= multiplier
            ruleTags.append(multiplier >= 1 ? "intensified" : "downtoned")
        }

        if hasNegator(before: match.tokenIndex, resolvedTokens: resolvedTokens) {
            if adjustedScore >= 0 {
                adjustedScore = -abs(adjustedScore) * 0.8
            } else {
                adjustedScore = abs(adjustedScore) * 0.6
            }
            ruleTags.append("negated")
        }

        if match.entry.category == .weakEvaluative {
            adjustedScore *= 0.85
            ruleTags.append("weakCue")
        }

        if let lastContrastiveIndex {
            if match.tokenIndex > lastContrastiveIndex {
                adjustedScore *= 1.25
                ruleTags.append("postContrast")
            } else if match.tokenIndex < lastContrastiveIndex {
                adjustedScore *= 0.75
                ruleTags.append("preContrast")
            }
        }

        if bangCount > 0, unit.tokens.count <= 25 {
            adjustedScore *= min(1.3, 1.0 + (0.1 * Double(bangCount)))
            ruleTags.append("exclamation")
        }

        if hasQuoteMarks, reportingVerbPresent {
            adjustedScore *= 0.85
            ruleTags.append("quotedEvidence")
        }

        return SentimentEvidenceHit(
            id: "\(unit.id)::\(match.tokenIndex)",
            surface: match.surface,
            lemma: match.lemma?.isEmpty == false ? match.lemma : nil,
            baseScore: match.entry.score,
            adjustedScore: adjustedScore,
            ruleTags: ruleTags,
            tokenIndex: match.tokenIndex,
            tokenLength: match.tokenLength
        )
    }

    private func hasNegator(
        before tokenIndex: Int,
        resolvedTokens: [String]
    ) -> Bool {
        guard tokenIndex > 0 else { return false }
        let start = max(0, tokenIndex - 3)
        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            if lexicon.contrastives.contains(resolvedTokens[candidateIndex]) {
                return false
            }
            if lexicon.negators.contains(resolvedTokens[candidateIndex]) {
                return true
            }
        }
        return false
    }

    private func precedingSentimentMultiplier(
        at tokenIndex: Int,
        resolvedTokens: [String],
        matches: [SentimentPhraseMatch]
    ) -> Double? {
        guard tokenIndex > 0 else { return nil }
        let start = max(0, tokenIndex - 2)
        for candidateIndex in stride(from: tokenIndex - 1, through: start, by: -1) {
            if lexicon.contrastives.contains(resolvedTokens[candidateIndex]) {
                return nil
            }
            let hasEarlierCueBetween = matches.contains { match in
                match.tokenIndex > candidateIndex && match.tokenIndex < tokenIndex
            }
            if hasEarlierCueBetween {
                return nil
            }
            if let multiplier = lexicon.intensifiers[resolvedTokens[candidateIndex]] {
                return multiplier
            }
        }
        return nil
    }

    private func buildRuleSummary(
        evidenceCount: Int,
        mixedEvidence: Bool,
        scopeNotes: [String]
    ) -> String {
        guard evidenceCount > 0 else { return "No strong lexical evidence" }
        let keyNotes = scopeNotes
            .filter { $0 != "lexicon" }
            .prefix(3)
            .joined(separator: ", ")
        if mixedEvidence {
            return keyNotes.isEmpty
                ? "Mixed evidence across \(evidenceCount) cues"
                : "Mixed evidence across \(evidenceCount) cues (\(keyNotes))"
        }
        return keyNotes.isEmpty
            ? "\(evidenceCount) lexical cue(s)"
            : "\(evidenceCount) cue(s) with \(keyNotes)"
    }

    private func resolveText(
        for input: SentimentInputText,
        request: SentimentRunRequest
    ) -> String {
        guard request.unit == .concordanceLine,
              request.contextBasis == .fullSentenceWhenAvailable,
              let documentText = input.documentText,
              let sentenceID = input.sentenceID else {
            return input.text
        }
        let indexed = indexDocument(documentText, DocumentCacheKey(text: documentText))
        return indexed.document.sentences.first(where: { $0.sentenceId == sentenceID })?.text ?? input.text
    }
}

