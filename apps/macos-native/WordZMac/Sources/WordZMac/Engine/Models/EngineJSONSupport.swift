import Foundation

typealias JSONObject = [String: Any]

enum EngineModelError: LocalizedError {
    case missingField(String)
    case invalidField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "缺少字段：\(field)"
        case .invalidField(let field):
            return "字段格式无效：\(field)"
        }
    }
}

enum JSONFieldReader {
    static func string(_ object: JSONObject, key: String, fallback: String = "") -> String {
        String(object[key] as? String ?? fallback)
    }

    static func bool(_ object: JSONObject, key: String, fallback: Bool = false) -> Bool {
        object[key] as? Bool ?? fallback
    }

    static func int(_ object: JSONObject, key: String, fallback: Int = 0) -> Int {
        if let value = object[key] as? Int {
            return value
        }
        if let value = object[key] as? Double {
            return Int(value)
        }
        return fallback
    }

    static func double(_ object: JSONObject, key: String, fallback: Double = 0) -> Double {
        if let value = object[key] as? Double {
            return value
        }
        if let value = object[key] as? Int {
            return Double(value)
        }
        return fallback
    }

    static func dictionary(_ object: JSONObject, key: String) -> JSONObject {
        object[key] as? JSONObject ?? [:]
    }

    static func array(_ object: JSONObject, key: String) -> [Any] {
        object[key] as? [Any] ?? []
    }

    static func stringArray(_ object: JSONObject, key: String) -> [String] {
        if let values = object[key] as? [String] {
            return values
        }
        if let values = object[key] as? [Any] {
            return values.compactMap { $0 as? String }
        }
        if let value = object[key] as? String {
            return value
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return []
    }
}

struct CorpusMetadataProfile: Codable, Equatable, Hashable, Sendable {
    let sourceLabel: String
    let yearLabel: String
    let genreLabel: String
    let tags: [String]

    static let empty = CorpusMetadataProfile()

    init(
        sourceLabel: String = "",
        yearLabel: String = "",
        genreLabel: String = "",
        tags: [String] = []
    ) {
        self.sourceLabel = sourceLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.yearLabel = yearLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.genreLabel = genreLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tags = Self.normalizeTags(tags)
    }

    init(json: JSONObject) {
        self.init(
            sourceLabel: JSONFieldReader.string(json, key: "sourceLabel"),
            yearLabel: JSONFieldReader.string(json, key: "yearLabel"),
            genreLabel: JSONFieldReader.string(json, key: "genreLabel"),
            tags: JSONFieldReader.stringArray(json, key: "tags")
        )
    }

    var hasContent: Bool {
        !sourceLabel.isEmpty || !yearLabel.isEmpty || !genreLabel.isEmpty || !tags.isEmpty
    }

    var tagsText: String {
        tags.joined(separator: ", ")
    }

    var jsonObject: JSONObject {
        [
            "sourceLabel": sourceLabel,
            "yearLabel": yearLabel,
            "genreLabel": genreLabel,
            "tags": tags
        ]
    }

    func compactSummary(in mode: AppLanguageMode) -> String {
        let parts = [sourceLabel, yearLabel, genreLabel] + Array(tags.prefix(2))
        let summary = parts.filter { !$0.isEmpty }.joined(separator: " · ")
        if !summary.isEmpty {
            return summary
        }
        return wordZText("未设置元数据", "No metadata yet", mode: mode)
    }

    func merged(over fallback: CorpusMetadataProfile) -> CorpusMetadataProfile {
        CorpusMetadataProfile(
            sourceLabel: sourceLabel.isEmpty ? fallback.sourceLabel : sourceLabel,
            yearLabel: yearLabel.isEmpty ? fallback.yearLabel : yearLabel,
            genreLabel: genreLabel.isEmpty ? fallback.genreLabel : genreLabel,
            tags: tags.isEmpty ? fallback.tags : tags
        )
    }

    private static func normalizeTags(_ tags: [String]) -> [String] {
        var seen = Set<String>()
        return tags
            .flatMap { $0.split(separator: ",").map(String.init) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }
}
