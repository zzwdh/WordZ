import Foundation

struct DerivedCompareRow: Equatable, Sendable {
    let row: CompareRow
    let metrics: DerivedCompareMetrics
}

struct DerivedCompareMetrics: Equatable, Sendable {
    let keyness: Double
    let effectSize: Double
    let pValue: Double
    let range: Double
    let referenceNormFreq: Double
    let referenceLabel: String
    let dominantLabel: String
    let distributionText: String
}

extension CompareSceneBuilder {
    func deriveMetrics(
        for row: CompareRow,
        referenceCorpusIDs: Set<String>,
        referenceLabel: String?,
        languageMode: AppLanguageMode
    ) -> DerivedCompareMetrics {
        let referenceEntries = row.perCorpus.filter { referenceCorpusIDs.contains($0.corpusId) }
        guard !referenceEntries.isEmpty, let referenceLabel else {
            return DerivedCompareMetrics(
                keyness: row.keyness,
                effectSize: row.effectSize,
                pValue: row.pValue,
                range: row.range,
                referenceNormFreq: row.referenceNormFreq,
                referenceLabel: wordZText("自动参考语料", "Automatic Reference", mode: languageMode),
                dominantLabel: row.dominantCorpusName,
                distributionText: row.perCorpus
                    .map { "\($0.corpusName) \($0.count) (\(String(format: "%.1f", $0.normFreq)))" }
                    .joined(separator: " · ")
            )
        }

        let referenceCount = referenceEntries.reduce(0) { $0 + $1.count }
        let referenceTokenCount = referenceEntries.reduce(0) { $0 + $1.tokenCount }
        let referenceNormFreq = referenceTokenCount > 0
            ? (Double(referenceCount) / Double(referenceTokenCount)) * 10_000
            : 0
        let targets = row.perCorpus.filter { !referenceCorpusIDs.contains($0.corpusId) }
        let targetCount = targets.reduce(0) { $0 + $1.count }
        let targetTokenCount = targets.reduce(0) { $0 + $1.tokenCount }
        let targetNormFreq = targetTokenCount > 0
            ? (Double(targetCount) / Double(targetTokenCount)) * 10_000
            : 0
        let keyness = signedLogLikelihood(
            targetCount: targetCount,
            targetTokenCount: targetTokenCount,
            referenceCount: referenceCount,
            referenceTokenCount: referenceTokenCount
        )
        let effectSize = logRatio(
            targetCount: targetCount,
            targetTokenCount: targetTokenCount,
            referenceCount: referenceCount,
            referenceTokenCount: referenceTokenCount
        )
        let pValue = erfc(sqrt(abs(keyness) / 2))
        let targetLabel: String
        if targets.count == 1 {
            targetLabel = targets[0].corpusName
        } else {
            targetLabel = wordZText("目标语料组", "Target Set", mode: languageMode)
        }
        let dominantLabel = keyness >= 0 ? targetLabel : referenceLabel
        let distributionText = row.perCorpus
            .map { corpus in
                let marker = referenceCorpusIDs.contains(corpus.corpusId) ? " [REF]" : ""
                return "\(corpus.corpusName)\(marker) \(corpus.count) (\(String(format: "%.1f", corpus.normFreq)))"
            }
            .joined(separator: " · ")

        return DerivedCompareMetrics(
            keyness: keyness,
            effectSize: effectSize,
            pValue: pValue,
            range: abs(targetNormFreq - referenceNormFreq),
            referenceNormFreq: referenceNormFreq,
            referenceLabel: referenceLabel,
            dominantLabel: dominantLabel,
            distributionText: distributionText
        )
    }

    func signedLogLikelihood(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let target = Double(max(0, targetCount))
        let reference = Double(max(0, referenceCount))
        let targetTotal = Double(max(0, targetTokenCount))
        let referenceTotal = Double(max(0, referenceTokenCount))
        let grandTotal = targetTotal + referenceTotal
        let observedTotal = target + reference

        guard targetTotal > 0, referenceTotal > 0, grandTotal > 0, observedTotal > 0 else {
            return 0
        }

        let pooledRate = observedTotal / grandTotal
        let expectedTarget = targetTotal * pooledRate
        let expectedReference = referenceTotal * pooledRate
        let targetTerm = target > 0 && expectedTarget > 0 ? target * log(target / expectedTarget) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * log(reference / expectedReference) : 0
        let statistic = 2 * (targetTerm + referenceTerm)

        let targetRate = target / targetTotal
        let referenceRate = reference / referenceTotal
        let sign = targetRate >= referenceRate ? 1.0 : -1.0
        return statistic * sign
    }

    func logRatio(
        targetCount: Int,
        targetTokenCount: Int,
        referenceCount: Int,
        referenceTokenCount: Int
    ) -> Double {
        let targetRate = (Double(max(0, targetCount)) + 0.5) / (Double(max(0, targetTokenCount)) + 1)
        let referenceRate = (Double(max(0, referenceCount)) + 0.5) / (Double(max(0, referenceTokenCount)) + 1)
        guard targetRate > 0, referenceRate > 0 else { return 0 }
        return log2(targetRate / referenceRate)
    }
}
