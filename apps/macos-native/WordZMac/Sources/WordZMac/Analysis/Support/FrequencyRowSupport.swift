import Foundation

enum FrequencyRowSortCriterion {
    case count
    case rank
    case range
    case word
}

enum FrequencyRowSortDirection {
    case ascending
    case descending
}

enum FrequencyRowSupport {
    static func lexicalRows(from rows: [FrequencyRow]) -> [FrequencyRow] {
        rows.filter { isLexicalWord($0.word) }
    }

    static func isLexicalWord(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    static func sortRows(
        _ rows: [FrequencyRow],
        criterion: FrequencyRowSortCriterion,
        direction: FrequencyRowSortDirection,
        definition: FrequencyMetricDefinition
    ) -> [FrequencyRow] {
        switch criterion {
        case .count:
            return sortComparableRows(rows, direction: direction) { $0.count }
        case .rank:
            return sortComparableRows(rows, direction: direction) { $0.rank }
        case .range:
            return sortComparableRows(rows, direction: direction) {
                rangeValue(for: $0, definition: definition)
            }
        case .word:
            return rows.sorted { lhs, rhs in
                let comparison = lhs.word.localizedCaseInsensitiveCompare(rhs.word)
                switch direction {
                case .ascending:
                    return comparison == .orderedAscending
                case .descending:
                    return comparison == .orderedDescending
                }
            }
        }
    }

    static func normalizedFrequency(
        for row: FrequencyRow,
        tokenCount: Int,
        definition: FrequencyMetricDefinition
    ) -> Double {
        guard tokenCount > 0 else { return 0 }
        return (Double(row.count) / Double(tokenCount)) * definition.normalizationUnit.multiplier
    }

    static func rangeValue(
        for row: FrequencyRow,
        definition: FrequencyMetricDefinition
    ) -> Int {
        switch definition.rangeMode {
        case .sentence:
            return row.sentenceRange
        case .paragraph:
            return row.paragraphRange
        }
    }

    static func normalizedRange(
        for row: FrequencyRow,
        paragraphCount: Int,
        sentenceCount: Int,
        definition: FrequencyMetricDefinition
    ) -> Double {
        let denominator: Int
        switch definition.rangeMode {
        case .sentence:
            denominator = max(sentenceCount, 1)
        case .paragraph:
            denominator = max(paragraphCount, 1)
        }
        return (Double(rangeValue(for: row, definition: definition)) / Double(denominator)) * 100
    }

    private static func sortComparableRows<Value: Comparable>(
        _ rows: [FrequencyRow],
        direction: FrequencyRowSortDirection,
        value: (FrequencyRow) -> Value
    ) -> [FrequencyRow] {
        rows.sorted { lhs, rhs in
            let leftValue = value(lhs)
            let rightValue = value(rhs)
            if leftValue == rightValue {
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            }
            switch direction {
            case .ascending:
                return leftValue < rightValue
            case .descending:
                return leftValue > rightValue
            }
        }
    }
}
