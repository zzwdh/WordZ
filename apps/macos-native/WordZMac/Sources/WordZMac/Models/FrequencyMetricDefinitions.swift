import Foundation

enum FrequencyNormalizationUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case perThousand
    case perTenThousand
    case perMillion

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .perThousand:
            return 1_000
        case .perTenThousand:
            return 10_000
        case .perMillion:
            return 1_000_000
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .perThousand:
            return wordZText("每千词", "Per 1K Tokens", mode: mode)
        case .perTenThousand:
            return wordZText("每万词", "Per 10K Tokens", mode: mode)
        case .perMillion:
            return wordZText("每百万词", "Per 1M Tokens", mode: mode)
        }
    }

    func compactLabel(in mode: AppLanguageMode) -> String {
        switch self {
        case .perThousand:
            return wordZText("/1K", "/1K", mode: mode)
        case .perTenThousand:
            return wordZText("/10K", "/10K", mode: mode)
        case .perMillion:
            return wordZText("/1M", "/1M", mode: mode)
        }
    }
}

enum FrequencyRangeMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case sentence
    case paragraph

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .sentence:
            return wordZText("按句子", "By Sentence", mode: mode)
        case .paragraph:
            return wordZText("按段落", "By Paragraph", mode: mode)
        }
    }

    func compactLabel(in mode: AppLanguageMode) -> String {
        switch self {
        case .sentence:
            return wordZText("句", "Sentence", mode: mode)
        case .paragraph:
            return wordZText("段", "Paragraph", mode: mode)
        }
    }
}

struct FrequencyMetricDefinition: Equatable, Codable, Sendable {
    var normalizationUnit: FrequencyNormalizationUnit
    var rangeMode: FrequencyRangeMode

    static let `default` = FrequencyMetricDefinition(
        normalizationUnit: .perTenThousand,
        rangeMode: .sentence
    )

    init(
        normalizationUnit: FrequencyNormalizationUnit = .perTenThousand,
        rangeMode: FrequencyRangeMode = .sentence
    ) {
        self.normalizationUnit = normalizationUnit
        self.rangeMode = rangeMode
    }

    func normFrequencyTitle(in mode: AppLanguageMode) -> String {
        "\(wordZText("标准频次", "Norm Frequency", mode: mode)) \(normalizationUnit.compactLabel(in: mode))"
    }

    func rangeTitle(in mode: AppLanguageMode) -> String {
        "\(wordZText("Range", "Range", mode: mode)) (\(rangeMode.compactLabel(in: mode)))"
    }

    func normRangeTitle(in mode: AppLanguageMode) -> String {
        "\(wordZText("Norm Range %", "Norm Range %", mode: mode)) (\(rangeMode.compactLabel(in: mode)))"
    }

    func summary(in mode: AppLanguageMode) -> String {
        "\(wordZText("口径", "Definition", mode: mode)): \(normalizationUnit.title(in: mode)) · \(rangeMode.title(in: mode))"
    }

    func exportNotes(in mode: AppLanguageMode, visibleRows: Int, totalRows: Int) -> [String] {
        [
            summary(in: mode),
            "\(wordZText("导出范围", "Export Scope", mode: mode)): \(wordZText("当前可见行", "Visible rows", mode: mode)) \(visibleRows) / \(totalRows)"
        ]
    }
}
