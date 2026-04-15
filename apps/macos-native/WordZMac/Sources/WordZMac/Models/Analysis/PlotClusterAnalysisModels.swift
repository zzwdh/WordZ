import Foundation

enum PlotScopeResolution: String, Identifiable, Codable, Sendable {
    case singleCorpus
    case corpusRange

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .singleCorpus:
            return wordZText("当前语料", "Current Corpus", mode: mode)
        case .corpusRange:
            return wordZText("当前语料范围", "Current Corpus Range", mode: mode)
        }
    }
}

struct PlotCorpusEntry: Equatable, Sendable {
    let corpusId: String
    let displayName: String
    let filePath: String
    let content: String
}

struct PlotHitMarker: Identifiable, Equatable, Sendable {
    let id: String
    let sentenceId: Int
    let tokenIndex: Int
    let normalizedPosition: Double
}

struct PlotRunRequest: Equatable, Sendable {
    let entries: [PlotCorpusEntry]
    let query: String
    let searchOptions: SearchOptionsState
    let scope: PlotScopeResolution

    var normalizedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct PlotRow: Identifiable, Equatable, Sendable {
    let id: String
    let corpusId: String
    let fileID: Int
    let filePath: String
    let displayName: String
    let fileTokens: Int
    let frequency: Int
    let normalizedFrequency: Double
    let hitMarkers: [PlotHitMarker]
}

struct PlotResult: Equatable, Sendable {
    let request: PlotRunRequest
    let totalHits: Int
    let totalFilesWithHits: Int
    let totalFiles: Int
    let rows: [PlotRow]
}

struct ClusterCorpusEntry: Equatable, Sendable {
    let corpusId: String
    let corpusName: String
    let content: String
}

enum ClusterMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case targetOnly
    case targetReference

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .targetOnly:
            return wordZText("仅目标语料", "Target Only", mode: mode)
        case .targetReference:
            return wordZText("目标 / 参考", "Target / Reference", mode: mode)
        }
    }
}

enum ClusterPunctuationMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case boundary
    case stripAndBridge

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .boundary:
            return wordZText("标点作边界", "Punctuation as Boundary", mode: mode)
        case .stripAndBridge:
            return wordZText("去标点并桥接", "Strip and Bridge", mode: mode)
        }
    }
}

enum ClusterSortMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case frequencyDescending
    case alphabeticalAscending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .frequencyDescending:
            return wordZText("频次降序", "Frequency Descending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        }
    }
}

struct ClusterRunRequest: Equatable, Sendable {
    let targetEntries: [ClusterCorpusEntry]
    let referenceEntries: [ClusterCorpusEntry]
    let caseSensitive: Bool
    let stopwordFilter: StopwordFilterState
    let punctuationMode: ClusterPunctuationMode
    let nValues: [Int]

    var mode: ClusterMode {
        referenceEntries.isEmpty ? .targetOnly : .targetReference
    }
}

struct ClusterRow: Identifiable, Equatable, Sendable {
    let phrase: String
    let n: Int
    let frequency: Int
    let normalizedFrequency: Double
    let range: Int
    let rangePercentage: Double
    let referenceFrequency: Int?
    let referenceNormalizedFrequency: Double?
    let referenceRange: Int?
    let logRatio: Double?

    var id: String {
        "\(n)|\(phrase.lowercased())"
    }
}

struct ClusterResult: Equatable, Sendable {
    let mode: ClusterMode
    let targetDocumentCount: Int
    let referenceDocumentCount: Int
    let targetTokenCount: Int
    let referenceTokenCount: Int
    let rows: [ClusterRow]
}
