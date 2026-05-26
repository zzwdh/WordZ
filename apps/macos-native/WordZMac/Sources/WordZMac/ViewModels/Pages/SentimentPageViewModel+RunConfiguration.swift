import Foundation

extension SentimentPageViewModel {
    var supportedUnits: [SentimentAnalysisUnit] {
        switch source {
        case .kwicVisible:
            return [.concordanceLine]
        case .topicSegments:
            return [.sourceSentence]
        default:
            return [.document, .sentence]
        }
    }

    var thresholds: SentimentThresholds {
        SentimentThresholds(
            decisionThreshold: decisionThreshold,
            minimumEvidence: minimumEvidence,
            neutralBias: neutralBias
        )
    }

    func canRun(hasOpenedCorpus: Bool, hasKWICRows: Bool, hasTopicRows: Bool) -> Bool {
        switch source {
        case .openedCorpus:
            return hasOpenedCorpus
        case .pastedText:
            return !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .kwicVisible:
            return hasKWICRows
        case .corpusCompare:
            return !selectedTargetCorpusItems().isEmpty
        case .topicSegments:
            return hasTopicRows
        }
    }

    func currentRunRequest(texts: [SentimentInputText]) -> SentimentRunRequest {
        let packRecommendation = packRecommendationService.resolve(
            selectedPackID: selectedDomainPackID,
            source: source,
            texts: texts
        )
        return SentimentRunRequest(
            source: source,
            unit: unit,
            contextBasis: contextBasis,
            thresholds: thresholds,
            texts: texts,
            backend: backend,
            domainPackID: selectedDomainPackID,
            effectiveDomainPackID: packRecommendation.usesAutomaticSelection ? packRecommendation.effectivePackID : nil,
            ruleProfile: selectedRuleProfile,
            calibrationProfile: currentCalibrationProfile,
            userLexiconBundleIDs: selectedRuleProfile.importedBundleIDs
        )
    }
}
