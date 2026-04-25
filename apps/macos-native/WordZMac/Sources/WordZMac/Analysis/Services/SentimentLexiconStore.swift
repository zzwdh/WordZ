import Foundation
import WordZAnalysis

private struct SentimentLexiconManifest: Decodable {
    let version: String
    let backendRevision: String?
    let resourceRevision: String?
    let bundledPackIDs: [SentimentDomainPackID]?
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

private struct SentimentShieldCue: Decodable {
    let term: String
    let reason: String
}

enum SentimentLexiconStoreLoadingError: LocalizedError, Sendable {
    case missingResource(name: String)
    case invalidResource(name: String, description: String)
    case unavailable(description: String)

    var errorDescription: String? {
        switch self {
        case .missingResource(let name):
            return "Missing sentiment resource: \(name).json"
        case .invalidResource(let name, let description):
            return "Unable to load sentiment resource \(name).json: \(description)"
        case .unavailable(let description):
            return description
        }
    }
}

struct SentimentLexiconEntry: Sendable {
    let term: String
    let tokens: [String]
    let score: Double
    let category: SentimentCueCategory
    let domainTags: [SentimentCueDomainTag]
    let matchMode: SentimentCueMatchMode
    let packID: SentimentDomainPackID?
    let isUserDefined: Bool
}

struct SentimentResolvedRulePack: Sendable {
    let activePackIDs: [SentimentDomainPackID]
    let entriesByLength: [Int: [SentimentLexiconEntry]]
    let maxEntryLength: Int
}

struct SentimentLexiconStore: Sendable {
    let manifest: SentimentRulePackManifest
    let packDescriptors: [SentimentRulePack]
    let coreEntries: [SentimentLexiconEntry]
    let entriesByPack: [SentimentDomainPackID: [SentimentLexiconEntry]]
    let negators: Set<String>
    let intensifiers: [String: Double]
    let contrastives: Set<String>
    let reportingVerbs: Set<String>
    let hedges: Set<String>
    let neutralShields: [String: String]
    let loadError: SentimentLexiconStoreLoadingError?

    var version: String { manifest.version }
    var backendRevision: String { manifest.backendRevision }
    var resourceRevision: String { manifest.resourceRevision }

    static let shared = loadShared()

    func resolvePack(
        domainPackID: SentimentDomainPackID,
        customEntries: [SentimentUserLexiconEntry]
    ) -> SentimentResolvedRulePack {
        let activePackIDs = activePackIDs(for: domainPackID)
        let bundledEntries = coreEntries + activePackIDs.flatMap { entriesByPack[$0] ?? [] }
        let overrideEntries = customEntries.compactMap(makeCustomEntry)
        let groupedEntries = Dictionary(grouping: bundledEntries + overrideEntries, by: { $0.tokens.count })
        return SentimentResolvedRulePack(
            activePackIDs: activePackIDs,
            entriesByLength: groupedEntries,
            maxEntryLength: groupedEntries.keys.max() ?? 1
        )
    }

    func activePackIDs(for selectedPackID: SentimentDomainPackID) -> [SentimentDomainPackID] {
        switch selectedPackID {
        case .general:
            return [.general]
        case .academic:
            return [.general, .academic]
        case .news:
            return [.general, .news]
        case .kwic:
            return [.general, .kwic]
        case .mixed:
            return manifest.bundledPackIDs
        }
    }

    private static func loadShared() -> SentimentLexiconStore {
        do {
            return try loadDefault()
        } catch let error as SentimentLexiconStoreLoadingError {
            return makeFallback(loadError: error)
        } catch {
            return makeFallback(
                loadError: .unavailable(description: error.localizedDescription)
            )
        }
    }

    private static func loadDefault() throws -> SentimentLexiconStore {
        let manifestResource: SentimentLexiconManifest = try loadJSON(named: "manifest")
        let manifest = SentimentRulePackManifest(
            version: manifestResource.version,
            backendRevision: manifestResource.backendRevision ?? "lexicon-rules-v3",
            resourceRevision: manifestResource.resourceRevision ?? manifestResource.version,
            bundledPackIDs: manifestResource.bundledPackIDs ?? SentimentDomainPackID.allCases
        )

        let coreEntries = makeEntries(
            try loadJSON(named: "core"),
            packID: nil
        )
        let generalEntries = makeEntries(
            try loadJSON(named: "general"),
            packID: .general
        )
        let academicEntries = makeEntries(
            try loadJSON(named: "academic"),
            packID: .academic
        )
        let newsEntries = makeEntries(
            try loadJSON(named: "news"),
            packID: .news
        )
        let kwicEntries = makeEntries(
            try loadJSON(named: "kwic"),
            packID: .kwic
        )

        let weightedCues: [SentimentWeightedCue] = try loadJSON(named: "intensifiers")
        let negators: [String] = try loadJSON(named: "negators")
        let contrastives: [String] = try loadJSON(named: "contrastives")
        let reportingVerbs: [String] = try loadJSON(named: "reporting_verbs")
        let hedges: [String] = try loadJSON(named: "hedges")
        let neutralShields: [SentimentShieldCue] = try loadJSON(named: "neutral_shields")

        let entriesByPack: [SentimentDomainPackID: [SentimentLexiconEntry]] = [
            .general: generalEntries,
            .academic: academicEntries,
            .news: newsEntries,
            .kwic: kwicEntries
        ]

        let packDescriptors = manifest.bundledPackIDs.map { packID in
            let resourceFiles: [String]
            switch packID {
            case .general:
                resourceFiles = ["core.json", "general.json"]
            case .academic:
                resourceFiles = ["core.json", "general.json", "academic.json", "hedges.json", "neutral_shields.json"]
            case .news:
                resourceFiles = ["core.json", "general.json", "news.json"]
            case .kwic:
                resourceFiles = ["core.json", "general.json", "kwic.json"]
            case .mixed:
                resourceFiles = ["core.json", "general.json", "academic.json", "news.json", "kwic.json", "hedges.json", "neutral_shields.json"]
            }
            let entryCount = coreEntries.count + entriesByPack.flatMap { key, value in
                manifest.bundledPackIDs.contains(key) ? value : []
            }.count
            return SentimentRulePack(
                id: packID,
                title: packID.rawValue,
                entryCount: entryCount,
                resourceFiles: resourceFiles
            )
        }

        return SentimentLexiconStore(
            manifest: manifest,
            packDescriptors: packDescriptors,
            coreEntries: coreEntries,
            entriesByPack: entriesByPack,
            negators: Set(negators.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            intensifiers: Dictionary(
                uniqueKeysWithValues: weightedCues.map {
                    (AnalysisTextNormalizationSupport.normalizeToken($0.term), $0.multiplier)
                }
            ),
            contrastives: Set(contrastives.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            reportingVerbs: Set(reportingVerbs.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            hedges: Set(hedges.map { AnalysisTextNormalizationSupport.normalizeToken($0) }),
            neutralShields: Dictionary(
                uniqueKeysWithValues: neutralShields.map {
                    (AnalysisTextNormalizationSupport.normalizeToken($0.term), $0.reason)
                }
            ),
            loadError: nil
        )
    }

    private static func makeFallback(
        loadError: SentimentLexiconStoreLoadingError
    ) -> SentimentLexiconStore {
        let bundledPackIDs = SentimentDomainPackID.allCases
        return SentimentLexiconStore(
            manifest: SentimentRulePackManifest(
                version: "sentiment-resources-unavailable",
                backendRevision: "lexicon-rules-unavailable",
                resourceRevision: "sentiment-resources-unavailable",
                bundledPackIDs: bundledPackIDs
            ),
            packDescriptors: bundledPackIDs.map {
                SentimentRulePack(
                    id: $0,
                    title: $0.rawValue,
                    entryCount: 0,
                    resourceFiles: []
                )
            },
            coreEntries: [],
            entriesByPack: [:],
            negators: [],
            intensifiers: [:],
            contrastives: [],
            reportingVerbs: [],
            hedges: [],
            neutralShields: [:],
            loadError: loadError
        )
    }

    private static func makeEntries(
        _ resources: [SentimentLexiconResourceEntry],
        packID: SentimentDomainPackID?
    ) -> [SentimentLexiconEntry] {
        resources.compactMap { entry in
            let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: entry.term)
            guard !tokens.isEmpty else { return nil }
            return SentimentLexiconEntry(
                term: entry.term,
                tokens: tokens,
                score: entry.score,
                category: entry.category ?? defaultCategory(for: entry.score),
                domainTags: entry.domainTags ?? [.general],
                matchMode: entry.matchMode ?? .either,
                packID: packID,
                isUserDefined: false
            )
        }
    }

    private func makeCustomEntry(_ entry: SentimentUserLexiconEntry) -> SentimentLexiconEntry? {
        let tokens = AnalysisTextNormalizationSupport.tokenizeWordLikeSegments(in: entry.term)
        guard !tokens.isEmpty else { return nil }
        return SentimentLexiconEntry(
            term: entry.term,
            tokens: tokens,
            score: entry.score,
            category: entry.category,
            domainTags: entry.domainTags,
            matchMode: entry.matchMode,
            packID: nil,
            isUserDefined: true
        )
    }

    private static func loadJSON<T: Decodable>(named name: String) throws -> T {
        guard let url = resourceURL(named: name) else {
            throw SentimentLexiconStoreLoadingError.missingResource(name: name)
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw SentimentLexiconStoreLoadingError.invalidResource(
                name: name,
                description: error.localizedDescription
            )
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
