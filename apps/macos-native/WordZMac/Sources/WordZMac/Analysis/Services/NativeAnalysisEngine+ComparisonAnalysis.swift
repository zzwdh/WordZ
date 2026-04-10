import Foundation

extension NativeAnalysisEngine {
    func runCompare(comparisonEntries: [CompareRequestEntry]) -> CompareResult {
        let prepared = comparisonEntries.map { entry -> PreparedCompareCorpus in
            let index = indexedDocument(for: entry.content)
            return PreparedCompareCorpus(
                entry: entry,
                tokenCount: index.tokenCount,
                typeCount: index.typeCount,
                ttr: index.ttr,
                sttr: index.sttr,
                topWord: index.sortedFrequencyRows.first?.word ?? "",
                topWordCount: index.sortedFrequencyRows.first?.count ?? 0,
                frequency: index.frequencyMap
            )
        }

        let allWords = Set(prepared.flatMap { $0.frequency.keys })
        let rows: [JSONObject] = allWords.map { word in
            let perCorpus: [JSONObject] = prepared.map { corpus in
                let count = corpus.frequency[word, default: 0]
                let normFreq = corpus.tokenCount > 0
                    ? (Double(count) / Double(corpus.tokenCount)) * 10_000
                    : 0
                return [
                    "corpusId": corpus.entry.corpusId,
                    "corpusName": corpus.entry.corpusName,
                    "folderName": corpus.entry.folderName,
                    "count": count,
                    "tokenCount": corpus.tokenCount,
                    "normFreq": normFreq
                ]
            }

            let total = perCorpus.reduce(0) { $0 + (JSONFieldReader.int($1, key: "count")) }
            let spread = perCorpus.filter { JSONFieldReader.int($0, key: "count") > 0 }.count
            let normFreqs = perCorpus.map { JSONFieldReader.double($0, key: "normFreq") }
            let range = (normFreqs.max() ?? 0) - (normFreqs.min() ?? 0)
            let dominant = perCorpus.max { lhs, rhs in
                let lhsNorm = JSONFieldReader.double(lhs, key: "normFreq")
                let rhsNorm = JSONFieldReader.double(rhs, key: "normFreq")
                if lhsNorm == rhsNorm {
                    return JSONFieldReader.int(lhs, key: "count") < JSONFieldReader.int(rhs, key: "count")
                }
                return lhsNorm < rhsNorm
            }
            let dominantCount = JSONFieldReader.int(dominant ?? [:], key: "count")
            let dominantTokenCount = JSONFieldReader.int(dominant ?? [:], key: "tokenCount")
            let referenceCount = max(0, total - dominantCount)
            let referenceTokenCount = max(0, prepared.reduce(0) { $0 + $1.tokenCount } - dominantTokenCount)
            let referenceNormFreq = referenceTokenCount > 0
                ? (Double(referenceCount) / Double(referenceTokenCount)) * 10_000
                : 0
            let keyness = Self.signedLogLikelihood(
                targetCount: dominantCount,
                targetTokenCount: dominantTokenCount,
                referenceCount: referenceCount,
                referenceTokenCount: referenceTokenCount
            )
            let effectSize = Self.logRatio(
                targetCount: dominantCount,
                targetTokenCount: dominantTokenCount,
                referenceCount: referenceCount,
                referenceTokenCount: referenceTokenCount
            )
            let pValue = erfc(sqrt(abs(keyness) / 2))

            return [
                "word": word,
                "total": total,
                "spread": spread,
                "range": range,
                "dominantCorpusName": JSONFieldReader.string(dominant ?? [:], key: "corpusName"),
                "keyness": keyness,
                "effectSize": effectSize,
                "pValue": pValue,
                "referenceNormFreq": referenceNormFreq,
                "perCorpus": perCorpus
            ] as JSONObject
        }

        let corpora: [JSONObject] = prepared.map { corpus in
            [
                "corpusId": corpus.entry.corpusId,
                "corpusName": corpus.entry.corpusName,
                "folderName": corpus.entry.folderName,
                "tokenCount": corpus.tokenCount,
                "typeCount": corpus.typeCount,
                "ttr": corpus.ttr,
                "sttr": corpus.sttr,
                "topWord": corpus.topWord,
                "topWordCount": corpus.topWordCount
            ]
        }

        return CompareResult(json: [
            "corpora": corpora,
            "rows": rows
        ])
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) -> KeywordResult {
        KeywordAnalyzer.analyze(
            target: targetEntry,
            reference: referenceEntry,
            options: options
        )
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) -> ChiSquareResult {
        let aa = Double(max(0, a))
        let bb = Double(max(0, b))
        let cc = Double(max(0, c))
        let dd = Double(max(0, d))

        let rowTotals = [aa + bb, cc + dd]
        let colTotals = [aa + cc, bb + dd]
        let total = rowTotals.reduce(0, +)

        let expected = [
            [rowTotals[0] * colTotals[0] / max(total, 1), rowTotals[0] * colTotals[1] / max(total, 1)],
            [rowTotals[1] * colTotals[0] / max(total, 1), rowTotals[1] * colTotals[1] / max(total, 1)]
        ]

        let observed = [[aa, bb], [cc, dd]]
        let correction = yates ? 0.5 : 0.0
        var chiSquare = 0.0
        for rowIndex in 0..<2 {
            for colIndex in 0..<2 {
                let obs = observed[rowIndex][colIndex]
                let exp = expected[rowIndex][colIndex]
                guard exp > 0 else { continue }
                let delta = max(0, abs(obs - exp) - correction)
                chiSquare += (delta * delta) / exp
            }
        }

        let totalInt = Int(total.rounded())
        let pValue = erfc(sqrt(max(chiSquare, 0) / 2))
        let phi = total > 0 ? sqrt(chiSquare / total) : 0
        let oddsRatio: Double?
        if bb == 0 || cc == 0 {
            oddsRatio = nil
        } else {
            oddsRatio = (aa * dd) / (bb * cc)
        }

        var warnings: [String] = []
        if expected.flatMap({ $0 }).contains(where: { $0 < 5 }) {
            warnings.append("期望频数中存在小于 5 的单元格，结果需谨慎解释。")
        }

        return ChiSquareResult(json: [
            "observed": observed,
            "expected": expected,
            "rowTotals": rowTotals,
            "colTotals": colTotals,
            "total": totalInt,
            "chiSquare": chiSquare,
            "degreesOfFreedom": 1,
            "pValue": pValue,
            "significantAt05": pValue < 0.05,
            "significantAt01": pValue < 0.01,
            "phi": phi,
            "oddsRatio": oddsRatio as Any,
            "yatesCorrection": yates,
            "warnings": warnings
        ])
    }
}
