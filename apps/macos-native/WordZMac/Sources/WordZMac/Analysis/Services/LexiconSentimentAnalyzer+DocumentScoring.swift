import Foundation

extension LexiconSentimentAnalyzer {
    func scoreDocument(
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

    func buildSentenceUnits(request: SentimentRunRequest) -> [SentimentScoringUnit] {
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

    func buildConcordanceUnits(request: SentimentRunRequest) -> [SentimentScoringUnit] {
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


    func makeRow(
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


    func resolveText(
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
