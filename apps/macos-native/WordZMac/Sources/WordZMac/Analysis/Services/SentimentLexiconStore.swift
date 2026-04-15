import Foundation
import WordZAnalysis

private struct SentimentLexiconManifest: Decodable {
    let version: String
    let backendRevision: String?
    let resourceRevision: String?
}

private struct SentimentLexiconResourceEntry: Decodable {
    let term: String
    let score: Double
    let category: SentimentCueCategory?
    let domainTags: [SentimentCueDomainTag]?
    let matchMode: SentimentCueMatchMode?
}

private struct SentimentWeightedCue: Decodable {
    let term: String
    let multiplier: Double
}

struct SentimentLexiconEntry: Sendable {
    let term: String
    let tokens: [String]
    let score: Double
    let category: SentimentCueCategory
    let domainTags: [SentimentCueDomainTag]
    let matchMode: SentimentCueMatchMode
}

struct SentimentLexiconStore: Sendable {
    let version: String
    let backendRevision: String
    let resourceRevision: String
    let entriesByLength: [Int: [SentimentLexiconEntry]]
    let maxEntryLength: Int
    let negators: Set<String>
    let intensifiers: [String: Double]
    let contrastives: Set<String>
    let reportingVerbs: Set<String>

    static let shared = loadDefault()

    private static func loadDefault() -> SentimentLexiconStore {
        let manifest: SentimentLexiconManifest = loadJSON(named: "manifest")
        let entryResources: [SentimentLexiconResourceEntry] = loadJSON(named: "lexicon")
        let weightedCues: [SentimentWeightedCue] = loadJSON(named: "intensifiers")
        let negators: [String] = loadJSON(named: "negators")
        let contrastives: [String] = loadJSON(named: "contrastives")
        let reportingVerbs: [String] = loadJSON(named: "reporting_verbs")

        let entries = entryResources.compactMap { entry -> SentimentLexiconEntry? in
            let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: entry.term)
            guard !tokens.isEmpty else { return nil }
            return SentimentLexiconEntry(
                term: entry.term,
                tokens: tokens,
                score: entry.score,
                category: entry.category ?? defaultCategory(for: entry.score),
                domainTags: entry.domainTags ?? [.core],
                matchMode: entry.matchMode ?? .either
            )
        }
        let groupedEntries = Dictionary(grouping: entries, by: { $0.tokens.count })
        let maxEntryLength = groupedEntries.keys.max() ?? 1

        return SentimentLexiconStore(
            version: manifest.version,
            backendRevision: manifest.backendRevision ?? "lexicon-rules-v2",
            resourceRevision: manifest.resourceRevision ?? manifest.version,
            entriesByLength: groupedEntries,
            maxEntryLength: maxEntryLength,
            negators: Set(negators.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            intensifiers: Dictionary(
                uniqueKeysWithValues: weightedCues.map {
                    (AnalysisTextNormalizationSupport.normalizeToken($0.term), $0.multiplier)
                }
            ),
            contrastives: Set(contrastives.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            reportingVerbs: Set(reportingVerbs.map { AnalysisTextNormalizationSupport.normalizeToken($0) })
        )
    }

    private static func loadJSON<T: Decodable>(named name: String) -> T {
        guard let url = resourceURL(named: name) else {
            fatalError("Missing sentiment resource: \(name).json")
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("Unable to load sentiment resource \(name).json: \(error)")
        }
    }

    private static func resourceURL(named name: String) -> URL? {
        if let bundled = WordZAnalysisResources.bundle.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Sentiment"
        ) {
            return bundled
        }

        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let fallback = sourceRoot
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Sentiment", isDirectory: true)
            .appendingPathComponent("\(name).json")

        guard FileManager.default.fileExists(atPath: fallback.path) else {
            return nil
        }
        return fallback
    }

    private static func defaultCategory(for score: Double) -> SentimentCueCategory {
        score >= 0 ? .corePositive : .coreNegative
    }
}
