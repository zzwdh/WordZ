import Foundation

extension LexiconSentimentAnalyzer {
    func buildRuleSummary(
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

    func effectiveThresholds(
        for request: SentimentRunRequest,
        calibrationProfile: SentimentCalibrationProfile
    ) -> SentimentThresholds {
        var thresholds = calibrationProfile.thresholds(overriding: request.thresholds)
        thresholds.neutralBias += calibrationProfile.domainBiasAdjustments[request.resolvedDomainPackID.rawValue] ?? 0
        return thresholds
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

