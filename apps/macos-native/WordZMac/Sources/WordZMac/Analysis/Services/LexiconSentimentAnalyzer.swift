import Foundation

final class LexiconSentimentAnalyzer: SentimentAnalyzing {
    let indexDocument: (String, DocumentCacheKey?) -> ParsedDocumentIndex
    let lexicon: SentimentLexiconStore
    let rulePackResolver: SentimentRulePackResolver
    let scopeSegmenter: SentimentScopeSegmenter
    let calibrationProfileProvider: SentimentCalibrationProfileProviding

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
}
