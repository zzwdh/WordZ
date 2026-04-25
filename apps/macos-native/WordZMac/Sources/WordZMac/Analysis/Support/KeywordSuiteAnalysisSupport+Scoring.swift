import Foundation

extension KeywordSuiteAnalyzer {
    static func buildRows(
        group: KeywordResultGroup,
        focus: KeywordPreparedSideAggregate,
        reference: KeywordPreparedSideAggregate,
        configuration: KeywordSuiteConfiguration
    ) -> [KeywordSuiteRow] {
        let focusGroup = focus.groups[group] ?? .empty
        let referenceGroup = reference.groups[group] ?? .empty
        let allItems = Set(focusGroup.counts.keys).union(referenceGroup.counts.keys)
        let thresholds = configuration.thresholds

        return allItems.compactMap { item in
            let focusFrequency = focusGroup.counts[item, default: 0]
            let referenceFrequency = referenceGroup.counts[item, default: 0]
            guard focusFrequency >= thresholds.minFocusFreq else { return nil }
            guard referenceFrequency >= thresholds.minReferenceFreq else { return nil }
            guard focusFrequency + referenceFrequency >= thresholds.minCombinedFreq else { return nil }

            let focusNorm = normalizedFrequency(
                count: focusFrequency,
                totalCount: focusGroup.totalCount
            )
            let referenceNorm = normalizedFrequency(
                count: referenceFrequency,
                totalCount: referenceGroup.totalCount
            )
            let score: Double
            switch configuration.statistic {
            case .logLikelihood:
                score = signedLogLikelihood(
                    focusCount: focusFrequency,
                    focusTotalCount: focusGroup.totalCount,
                    referenceCount: referenceFrequency,
                    referenceTotalCount: referenceGroup.totalCount
                )
            case .chiSquare:
                score = signedChiSquare(
                    focusCount: focusFrequency,
                    focusTotalCount: focusGroup.totalCount,
                    referenceCount: referenceFrequency,
                    referenceTotalCount: referenceGroup.totalCount
                )
            }
            guard score != 0 else { return nil }

            let rowDirection: KeywordRowDirection = score > 0 ? .positive : .negative
            if configuration.direction == .positive, rowDirection != .positive {
                return nil
            }
            if configuration.direction == .negative, rowDirection != .negative {
                return nil
            }

            let logRatio = logRatio(
                focusCount: focusFrequency,
                focusTotalCount: focusGroup.totalCount,
                referenceCount: referenceFrequency,
                referenceTotalCount: referenceGroup.totalCount
            )
            let pValue = erfc(sqrt(abs(score) / 2))
            guard pValue <= thresholds.maxPValue else { return nil }
            guard abs(logRatio) >= thresholds.minAbsLogRatio else { return nil }

            let preferredExample = focusGroup.examples[item] ?? referenceGroup.examples[item]
            return KeywordSuiteRow(
                group: group,
                item: item,
                direction: rowDirection,
                focusFrequency: focusFrequency,
                referenceFrequency: referenceFrequency,
                focusNormalizedFrequency: focusNorm,
                referenceNormalizedFrequency: referenceNorm,
                keynessScore: score,
                logRatio: logRatio,
                pValue: pValue,
                focusRange: focusGroup.corpusRanges[item]?.count ?? 0,
                referenceRange: referenceGroup.corpusRanges[item]?.count ?? 0,
                example: preferredExample?.text ?? "",
                focusExampleCorpusID: focusGroup.examples[item]?.corpusID,
                referenceExampleCorpusID: referenceGroup.examples[item]?.corpusID
            )
        }
        .sorted(by: compareRows)
    }

    static func compareRows(_ lhs: KeywordSuiteRow, _ rhs: KeywordSuiteRow) -> Bool {
        let lhsAbs = abs(lhs.keynessScore)
        let rhsAbs = abs(rhs.keynessScore)
        if lhsAbs != rhsAbs {
            return lhsAbs > rhsAbs
        }
        if lhs.direction != rhs.direction {
            return lhs.direction == .positive
        }
        if lhs.focusFrequency != rhs.focusFrequency {
            return lhs.focusFrequency > rhs.focusFrequency
        }
        return lhs.item.localizedCaseInsensitiveCompare(rhs.item) == .orderedAscending
    }

    static func normalizedFrequency(count: Int, totalCount: Int) -> Double {
        guard totalCount > 0 else { return 0 }
        return (Double(count) / Double(totalCount)) * normalizationBase
    }

    static func signedLogLikelihood(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let focus = Double(max(0, focusCount))
        let reference = Double(max(0, referenceCount))
        let focusTokens = Double(max(0, focusTotalCount))
        let referenceTokens = Double(max(0, referenceTotalCount))
        guard focusTokens > 0, referenceTokens > 0 else { return 0 }

        let observedTotal = focus + reference
        let tokenTotal = focusTokens + referenceTokens
        guard observedTotal > 0, tokenTotal > 0 else { return 0 }

        let expectedFocus = observedTotal * (focusTokens / tokenTotal)
        let expectedReference = observedTotal * (referenceTokens / tokenTotal)
        let focusTerm = focus > 0 && expectedFocus > 0 ? focus * Foundation.log(focus / expectedFocus) : 0
        let referenceTerm = reference > 0 && expectedReference > 0 ? reference * Foundation.log(reference / expectedReference) : 0
        let value = 2 * (focusTerm + referenceTerm)

        let focusNorm = focus / focusTokens
        let referenceNorm = reference / referenceTokens
        return focusNorm >= referenceNorm ? value : -value
    }

    static func signedChiSquare(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let a = Double(max(0, focusCount))
        let b = Double(max(0, focusTotalCount - focusCount))
        let c = Double(max(0, referenceCount))
        let d = Double(max(0, referenceTotalCount - referenceCount))
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
                let delta = observed[rowIndex][columnIndex] - exp
                statistic += (delta * delta) / exp
            }
        }

        let focusNorm = rowTotals[0] > 0 ? a / rowTotals[0] : 0
        let referenceNorm = rowTotals[1] > 0 ? c / rowTotals[1] : 0
        return focusNorm >= referenceNorm ? statistic : -statistic
    }

    static func logRatio(
        focusCount: Int,
        focusTotalCount: Int,
        referenceCount: Int,
        referenceTotalCount: Int
    ) -> Double {
        let smoothing = 0.5
        let focusRate = (Double(focusCount) + smoothing) / (Double(max(focusTotalCount, 0)) + smoothing)
        let referenceRate = (Double(referenceCount) + smoothing) / (Double(max(referenceTotalCount, 0)) + smoothing)
        guard focusRate > 0, referenceRate > 0 else { return 0 }
        return Foundation.log2(focusRate / referenceRate)
    }
}
