import Foundation

enum TextPreprocessor {
    static func preprocess(_ text: String, lowercased: Bool) -> String {
        let normalizedLineBreaks = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .precomposedStringWithCompatibilityMapping
        let foldingOptions: String.CompareOptions = lowercased ? [.caseInsensitive, .widthInsensitive] : [.widthInsensitive]
        return normalizedLineBreaks.folding(options: foldingOptions, locale: nil)
    }
}

enum Tokenizer {
    private static let searchableScalars = CharacterSet.alphanumerics
    private static let joinerScalars: Set<UnicodeScalar> = ["'", "-", "’"]

    static func tokenize(_ text: String, removePunctuation: Bool) -> [Token] {
        guard !text.isEmpty else { return [] }

        var tokens: [Token] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            let cleaned = buffer.trimmingCharacters(in: CharacterSet(charactersIn: "'-’"))
            if !cleaned.isEmpty {
                tokens.append(Token(surface: cleaned, normalized: cleaned))
            }
            buffer.removeAll(keepingCapacity: true)
        }

        for scalar in text.unicodeScalars {
            if searchableScalars.contains(scalar) {
                buffer.unicodeScalars.append(scalar)
                continue
            }

            if joinerScalars.contains(scalar), !buffer.isEmpty {
                if removePunctuation {
                    continue
                }
                buffer.unicodeScalars.append(scalar)
                continue
            }

            flushBuffer()
        }

        flushBuffer()
        return tokens
    }
}

enum FrequencyAnalyzer {
    static func buildFrequencyTable(from tokens: [Token], stopwordFilter: StopwordFilterState) -> FrequencyTable {
        let stopwordSet = Set(stopwordFilter.parsedWords)
        var counts: [String: Int] = [:]
        var retainedTokenCount = 0

        for token in tokens {
            let normalized = token.normalized
            guard !normalized.isEmpty else { continue }
            if !matchesStopwordPolicy(normalized, filter: stopwordFilter, stopwordSet: stopwordSet) {
                continue
            }
            counts[normalized, default: 0] += 1
            retainedTokenCount += 1
        }

        return FrequencyTable(counts: counts, tokenCount: retainedTokenCount)
    }

    private static func matchesStopwordPolicy(
        _ token: String,
        filter: StopwordFilterState,
        stopwordSet: Set<String>
    ) -> Bool {
        guard filter.enabled, !stopwordSet.isEmpty else { return true }
        let contains = stopwordSet.contains(token)
        switch filter.mode {
        case .exclude:
            return !contains
        case .include:
            return contains
        }
    }
}

enum KeywordAnalyzer {
    static let normalizationBase = 1_000_000.0

    static func analyze(
        target: KeywordRequestEntry,
        reference: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) -> KeywordResult {
        let targetCorpus = target.asCorpus()
        let referenceCorpus = reference.asCorpus()

        let preparedTarget = TextPreprocessor.preprocess(targetCorpus.text, lowercased: options.lowercased)
        let preparedReference = TextPreprocessor.preprocess(referenceCorpus.text, lowercased: options.lowercased)

        let targetTokens = Tokenizer.tokenize(preparedTarget, removePunctuation: options.removePunctuation)
        let referenceTokens = Tokenizer.tokenize(preparedReference, removePunctuation: options.removePunctuation)

        let targetTable = FrequencyAnalyzer.buildFrequencyTable(from: targetTokens, stopwordFilter: options.stopwordFilter)
        let referenceTable = FrequencyAnalyzer.buildFrequencyTable(from: referenceTokens, stopwordFilter: options.stopwordFilter)

        let targetSummary = KeywordCorpusSummary(
            corpusId: target.corpusId,
            corpusName: target.corpusName,
            folderName: target.folderName,
            tokenCount: targetTable.tokenCount,
            typeCount: targetTable.typeCount
        )
        let referenceSummary = KeywordCorpusSummary(
            corpusId: reference.corpusId,
            corpusName: reference.corpusName,
            folderName: reference.folderName,
            tokenCount: referenceTable.tokenCount,
            typeCount: referenceTable.typeCount
        )

        let allWords = Set(targetTable.counts.keys).union(referenceTable.counts.keys)
        let minimumFrequency = max(1, options.minimumFrequency)
        let unsortedRows = allWords.compactMap { term -> KeywordResultRow? in
            let targetFrequency = targetTable.frequency(of: term)
            let referenceFrequency = referenceTable.frequency(of: term)
            guard targetFrequency >= minimumFrequency else { return nil }

            let targetNorm = targetTable.normalizedFrequency(of: term, per: normalizationBase)
            let referenceNorm = referenceTable.normalizedFrequency(of: term, per: normalizationBase)
            guard targetNorm > referenceNorm else { return nil }

            let score: Double
            switch options.statistic {
            case .logLikelihood:
                score = signedLogLikelihood(
                    targetCount: targetFrequency,
                    targetTokenCount: targetTable.tokenCount,
                    referenceCount: referenceFrequency,
                    referenceTokenCount: referenceTable.tokenCount
                )
            case .chiSquare:
                score = chiSquare(
                    targetCount: targetFrequency,
                    targetTokenCount: targetTable.tokenCount,
                    referenceCount: referenceFrequency,
                    referenceTokenCount: referenceTable.tokenCount
                )
            }

            guard score > 0 else { return nil }

            return KeywordResultRow(
                word: term,
                rank: 0,
                targetFrequency: targetFrequency,
                referenceFrequency: referenceFrequency,
                targetNormalizedFrequency: targetNorm,
                referenceNormalizedFrequency: referenceNorm,
                keynessScore: score,
                logRatio: logRatio(
                    targetCount: targetFrequency,
                    targetTokenCount: targetTable.tokenCount,
                    referenceCount: referenceFrequency,
                    referenceTokenCount: referenceTable.tokenCount
                ),
                pValue: erfc(sqrt(max(score, 0) / 2))
            )
        }

        let rankedRows = unsortedRows
            .sorted { lhs, rhs in
                if lhs.keynessScore == rhs.keynessScore {
                    if lhs.targetFrequency == rhs.targetFrequency {
                        return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
                    }
                    return lhs.targetFrequency > rhs.targetFrequency
                }
                return lhs.keynessScore > rhs.keynessScore
            }
            .enumerated()
            .map { index, row in
                KeywordResultRow(
                    word: row.word,
                    rank: index + 1,
                    targetFrequency: row.targetFrequency,
                    referenceFrequency: row.referenceFrequency,
                    targetNormalizedFrequency: row.targetNormalizedFrequency,
                    referenceNormalizedFrequency: row.referenceNormalizedFrequency,
                    keynessScore: row.keynessScore,
                    logRatio: row.logRatio,
                    pValue: row.pValue
                )
            }

        return KeywordResult(
            statistic: options.statistic,
            targetCorpus: targetSummary,
            referenceCorpus: referenceSummary,
            rows: rankedRows
        )
    }

    private static func signedLogLikelihood(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let target = Double(max(0, targetCount))
        let reference = Double(max(0, referenceCount))
        let targetTokens = Double(max(0, targetTokenCount))
        let referenceTokens = Double(max(0, referenceTokenCount))
        guard targetTokens > 0, referenceTokens > 0 else { return 0 }

        let observedTotal = target + reference
        let tokenTotal = targetTokens + referenceTokens
        guard observedTotal > 0, tokenTotal > 0 else { return 0 }

        let expectedTarget = observedTotal * (targetTokens / tokenTotal)
        let expectedReference = observedTotal * (referenceTokens / tokenTotal)

        let targetTerm = target > 0 && expectedTarget > 0 ? target * Foundation.log(target / expectedTarget) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * Foundation.log(reference / expectedReference) : 0
        let value = 2 * (targetTerm + referenceTerm)

        let targetNorm = target / targetTokens
        let referenceNorm = reference / referenceTokens
        return targetNorm >= referenceNorm ? value : -value
    }

    private static func chiSquare(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let a = Double(max(0, targetCount))
        let b = Double(max(0, targetTokenCount - targetCount))
        let c = Double(max(0, referenceCount))
        let d = Double(max(0, referenceTokenCount - referenceCount))
        let total = a + b + c + d
        guard total > 0 else { return 0 }

        let rowTotals = [a + b, c + d]
        let columnTotals = [a + c, b + d]
        let expected = [
            [rowTotals[0] * columnTotals[0] / total, rowTotals[0] * columnTotals[1] / total],
            [rowTotals[1] * columnTotals[0] / total, rowTotals[1] * columnTotals[1] / total]
        ]
        let observed = [[a, b], [c, d]]

        var statistic = 0.0
        for rowIndex in 0..<2 {
            for columnIndex in 0..<2 {
                let exp = expected[rowIndex][columnIndex]
                guard exp > 0 else { continue }
                let obs = observed[rowIndex][columnIndex]
                let delta = obs - exp
                statistic += (delta * delta) / exp
            }
        }

        let targetNorm = rowTotals[0] > 0 ? a / rowTotals[0] : 0
        let referenceNorm = rowTotals[1] > 0 ? c / rowTotals[1] : 0
        return targetNorm >= referenceNorm ? statistic : -statistic
    }

    private static func logRatio(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let smoothing = 0.5
        let targetRate = (Double(targetCount) + smoothing) / (Double(max(targetTokenCount, 0)) + smoothing)
        let referenceRate = (Double(referenceCount) + smoothing) / (Double(max(referenceTokenCount, 0)) + smoothing)
        guard targetRate > 0, referenceRate > 0 else { return 0 }
        return Foundation.log2(targetRate / referenceRate)
    }
}
