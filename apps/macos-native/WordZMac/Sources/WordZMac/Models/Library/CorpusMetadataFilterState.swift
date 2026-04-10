import Foundation

struct CorpusMetadataFilterState: Equatable, Sendable, Codable {
    var sourceQuery: String
    var yearQuery: String
    var genreQuery: String
    var tagsQuery: String

    static let empty = CorpusMetadataFilterState(
        sourceQuery: "",
        yearQuery: "",
        genreQuery: "",
        tagsQuery: ""
    )

    var activeFilterCount: Int {
        [sourceQuery, yearQuery, genreQuery, tagsQuery]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    var isEmpty: Bool {
        activeFilterCount == 0
    }

    init(
        sourceQuery: String,
        yearQuery: String,
        genreQuery: String,
        tagsQuery: String
    ) {
        self.sourceQuery = sourceQuery
        self.yearQuery = yearQuery
        self.genreQuery = genreQuery
        self.tagsQuery = tagsQuery
    }

    init(json: JSONObject) {
        self.sourceQuery = JSONFieldReader.string(json, key: "sourceQuery")
        self.yearQuery = JSONFieldReader.string(json, key: "yearQuery")
        self.genreQuery = JSONFieldReader.string(json, key: "genreQuery")
        self.tagsQuery = JSONFieldReader.string(json, key: "tagsQuery")
    }

    var jsonObject: JSONObject {
        [
            "sourceQuery": sourceQuery,
            "yearQuery": yearQuery,
            "genreQuery": genreQuery,
            "tagsQuery": tagsQuery
        ]
    }

    func summaryText(in mode: AppLanguageMode) -> String? {
        guard activeFilterCount > 0 else { return nil }
        if mode == .english {
            let noun = activeFilterCount == 1 ? "filter" : "filters"
            return "\(activeFilterCount) \(noun) applied"
        }
        return "已应用 \(activeFilterCount) 个筛选条件"
    }

    func matches(_ metadata: CorpusMetadataProfile) -> Bool {
        matchesField(sourceQuery, value: metadata.sourceLabel)
            && matchesField(yearQuery, value: metadata.yearLabel)
            && matchesField(genreQuery, value: metadata.genreLabel)
            && matchesTags(tagsQuery, tags: metadata.tags)
    }

    private func matchesField(_ query: String, value: String) -> Bool {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else { return true }
        return value.localizedCaseInsensitiveContains(normalizedQuery)
    }

    private func matchesTags(_ query: String, tags: [String]) -> Bool {
        let components = query
            .split(whereSeparator: { [",", "，", ";", "；", "\n"].contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !components.isEmpty else { return true }
        return components.allSatisfy { term in
            tags.contains(where: { $0.localizedCaseInsensitiveContains(term) })
        }
    }
}
