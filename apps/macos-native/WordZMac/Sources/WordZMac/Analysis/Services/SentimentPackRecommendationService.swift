import Foundation

enum SentimentPackRecommendationReason: String, Sendable {
    case manualSelection
    case kwicSource
    case newsSignals
}

struct SentimentPackRecommendation: Equatable, Sendable {
    let selectedPackID: SentimentDomainPackID
    let effectivePackID: SentimentDomainPackID
    let reason: SentimentPackRecommendationReason

    var usesAutomaticSelection: Bool {
        selectedPackID != effectivePackID
    }

    func summary(in mode: AppLanguageMode) -> String {
        if usesAutomaticSelection {
            return "\(wordZText("自动", "Auto", mode: mode)) -> \(effectivePackID.title(in: mode))"
        }
        return selectedPackID.title(in: mode)
    }
}

struct SentimentPackRecommendationService: Sendable {
    private let lexicon: SentimentLexiconStore
    private let newsStyleTerms: Set<String> = [
        "agency", "agencies", "analyst", "analysts", "authorities", "board", "briefing",
        "candidate", "candidates", "council", "court", "filing", "governor", "hearing",
        "judge", "judges", "lawmakers", "leader", "leaders", "lawsuit", "mayor", "minister",
        "notice", "official", "officials", "policy", "proposal", "proposals", "regulator",
        "regulators", "resident", "residents", "spokesperson", "statement", "vote", "voters"
    ]
    private let newsPhrases: [String] = [
        "according to",
        "after the briefing",
        "after the vote",
        "before noon",
        "court records",
        "in a court filing",
        "city officials",
        "court filing",
        "officials said",
        "official statement",
        "press briefing",
        "the agency issued",
        "the spokesperson said"
    ]

    init(lexicon: SentimentLexiconStore = .shared) {
        self.lexicon = lexicon
    }

    func resolve(
        selectedPackID: SentimentDomainPackID,
        source: SentimentInputSource,
        texts: [SentimentInputText]
    ) -> SentimentPackRecommendation {
        guard selectedPackID == .mixed else {
            return SentimentPackRecommendation(
                selectedPackID: selectedPackID,
                effectivePackID: selectedPackID,
                reason: .manualSelection
            )
        }

        if source == .kwicVisible {
            return SentimentPackRecommendation(
                selectedPackID: selectedPackID,
                effectivePackID: .kwic,
                reason: .kwicSource
            )
        }

        if shouldPreferNews(texts: texts) {
            return SentimentPackRecommendation(
                selectedPackID: selectedPackID,
                effectivePackID: .news,
                reason: .newsSignals
            )
        }

        return SentimentPackRecommendation(
            selectedPackID: selectedPackID,
            effectivePackID: selectedPackID,
            reason: .manualSelection
        )
    }

    private func shouldPreferNews(texts: [SentimentInputText]) -> Bool {
        guard !texts.isEmpty else { return false }

        let scoredTexts = texts.map(newsSignalScore)
        let matchedTexts = scoredTexts.filter { $0 >= 3 }.count
        let totalScore = scoredTexts.reduce(0, +)

        if matchedTexts >= max(1, texts.count / 3) {
            return true
        }

        let averageScore = Double(totalScore) / Double(max(texts.count, 1))
        return averageScore >= 2.0 || totalScore >= 6
    }

    private func newsSignalScore(for input: SentimentInputText) -> Int {
        let normalizedText = input.text.localizedLowercase
        let normalizedTitle = input.sourceTitle.localizedLowercase
        let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: normalizedText)

        let reportingHits = tokens.filter { lexicon.reportingVerbs.contains($0) }.count
        let styleHits = tokens.filter { newsStyleTerms.contains($0) }.count
        let quotedHit = containsQuotes(normalizedText) ? 1 : 0
        let phraseHits = newsPhrases.filter { normalizedText.contains($0) || normalizedTitle.contains($0) }.count
        let titleHits = newsStyleTerms.filter { normalizedTitle.contains($0) }.count

        return (reportingHits * 2) + styleHits + (quotedHit * 2) + (phraseHits * 2) + titleHits
    }

    private func containsQuotes(_ text: String) -> Bool {
        text.contains("\"") || text.contains("“") || text.contains("”")
    }
}
