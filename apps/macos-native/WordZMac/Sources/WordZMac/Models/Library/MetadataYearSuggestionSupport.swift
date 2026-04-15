import Foundation

struct MetadataYearRangeShortcut: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case currentYear
        case recentThreeYears
        case recentFiveYears

        func title(in mode: AppLanguageMode) -> String {
            switch self {
            case .currentYear:
                return wordZText("本年", "This Year", mode: mode)
            case .recentThreeYears:
                return wordZText("近 3 年", "Last 3 Years", mode: mode)
            case .recentFiveYears:
                return wordZText("近 5 年", "Last 5 Years", mode: mode)
            }
        }
    }

    let kind: Kind
    let from: String
    let to: String

    var id: String { kind.rawValue }
}

enum MetadataYearSuggestionSupport {
    private static let yearRegex = try? NSRegularExpression(pattern: #"(?<!\d)\d{4}(?!\d)"#)

    static func extractYears(from value: String) -> [Int] {
        guard let yearRegex else { return [] }
        let fullRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return yearRegex.matches(in: value, range: fullRange).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return Int(value[range])
        }
    }

    static func suggestedYears(
        from corpora: [LibraryCorpusItem],
        limit: Int = 12
    ) -> [String] {
        let years = corpora
            .flatMap { extractYears(from: $0.metadata.yearLabel) }

        return Array(Set(years))
            .sorted(by: >)
            .prefix(limit)
            .map(String.init)
    }

    static func commonYearLabels(
        from corpora: [LibraryCorpusItem],
        limit: Int = 8
    ) -> [String] {
        let labels = corpora
            .map { $0.metadata.yearLabel.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let counts = labels.reduce(into: [String: Int]()) { partialResult, label in
            partialResult[label, default: 0] += 1
        }

        return counts
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }

                let lhsMostRecent = extractYears(from: lhs.key).max() ?? Int.min
                let rhsMostRecent = extractYears(from: rhs.key).max() ?? Int.min
                if lhsMostRecent != rhsMostRecent {
                    return lhsMostRecent > rhsMostRecent
                }

                return lhs.key.localizedStandardCompare(rhs.key) == .orderedAscending
            }
            .prefix(limit)
            .map(\.key)
    }

    static func quickYearLabels(
        referenceDate: Date,
        calendar: Calendar = .current,
        count: Int = 5
    ) -> [String] {
        let currentYear = calendar.component(.year, from: referenceDate)
        return (0..<max(count, 0)).map { String(currentYear - $0) }
    }

    static func rangeShortcuts(
        referenceDate: Date,
        calendar: Calendar = .current
    ) -> [MetadataYearRangeShortcut] {
        let currentYear = calendar.component(.year, from: referenceDate)
        return [
            MetadataYearRangeShortcut(
                kind: .currentYear,
                from: String(currentYear),
                to: String(currentYear)
            ),
            MetadataYearRangeShortcut(
                kind: .recentThreeYears,
                from: String(currentYear - 2),
                to: String(currentYear)
            ),
            MetadataYearRangeShortcut(
                kind: .recentFiveYears,
                from: String(currentYear - 4),
                to: String(currentYear)
            )
        ]
    }
}
