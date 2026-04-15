import Foundation

struct CorpusMetadataFilterState: Equatable, Sendable, Codable {
    var sourceQuery: String
    var yearQuery: String
    var yearFrom: String?
    var yearTo: String?
    var genreQuery: String
    var tagsQuery: String

    static let empty = CorpusMetadataFilterState(
        sourceQuery: "",
        yearQuery: "",
        yearFrom: nil,
        yearTo: nil,
        genreQuery: "",
        tagsQuery: ""
    )

    var activeFilterCount: Int {
        var count = 0
        if !sourceQuery.isEmpty { count += 1 }
        if hasYearFilter { count += 1 }
        if !genreQuery.isEmpty { count += 1 }
        if !tagsQuery.isEmpty { count += 1 }
        return count
    }

    var isEmpty: Bool {
        activeFilterCount == 0
    }

    init(
        sourceQuery: String,
        yearQuery: String = "",
        yearFrom: String? = nil,
        yearTo: String? = nil,
        genreQuery: String,
        tagsQuery: String
    ) {
        self.sourceQuery = sourceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.yearQuery = yearQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedBounds = Self.normalizedYearBounds(yearFrom: yearFrom, yearTo: yearTo)
        self.yearFrom = normalizedBounds.from
        self.yearTo = normalizedBounds.to
        self.genreQuery = genreQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        self.tagsQuery = tagsQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(json: JSONObject) {
        let sourceQuery = JSONFieldReader.string(json, key: "sourceQuery")
        let rawYearQuery = JSONFieldReader.string(json, key: "yearQuery")
        let decodedYearFrom = Self.decodeYearBound(from: json, key: "yearFrom")
        let decodedYearTo = Self.decodeYearBound(from: json, key: "yearTo")

        if decodedYearFrom == nil,
           decodedYearTo == nil,
           let migratedSingleYear = Self.parseSingleYear(rawYearQuery) {
            self.init(
                sourceQuery: sourceQuery,
                yearQuery: "",
                yearFrom: "\(migratedSingleYear)",
                yearTo: "\(migratedSingleYear)",
                genreQuery: JSONFieldReader.string(json, key: "genreQuery"),
                tagsQuery: JSONFieldReader.string(json, key: "tagsQuery")
            )
        } else {
            self.init(
                sourceQuery: sourceQuery,
                yearQuery: rawYearQuery,
                yearFrom: decodedYearFrom,
                yearTo: decodedYearTo,
                genreQuery: JSONFieldReader.string(json, key: "genreQuery"),
                tagsQuery: JSONFieldReader.string(json, key: "tagsQuery")
            )
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let sourceQuery = try container.decodeIfPresent(String.self, forKey: .sourceQuery) ?? ""
        let rawYearQuery = try container.decodeIfPresent(String.self, forKey: .yearQuery) ?? ""
        let decodedYearFrom = Self.decodeYearBound(from: container, key: .yearFrom)
        let decodedYearTo = Self.decodeYearBound(from: container, key: .yearTo)
        let genreQuery = try container.decodeIfPresent(String.self, forKey: .genreQuery) ?? ""
        let tagsQuery = try container.decodeIfPresent(String.self, forKey: .tagsQuery) ?? ""

        if decodedYearFrom == nil,
           decodedYearTo == nil,
           let migratedSingleYear = Self.parseSingleYear(rawYearQuery) {
            self.init(
                sourceQuery: sourceQuery,
                yearQuery: "",
                yearFrom: "\(migratedSingleYear)",
                yearTo: "\(migratedSingleYear)",
                genreQuery: genreQuery,
                tagsQuery: tagsQuery
            )
        } else {
            self.init(
                sourceQuery: sourceQuery,
                yearQuery: rawYearQuery,
                yearFrom: decodedYearFrom,
                yearTo: decodedYearTo,
                genreQuery: genreQuery,
                tagsQuery: tagsQuery
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sourceQuery, forKey: .sourceQuery)
        try container.encode(yearQuery, forKey: .yearQuery)
        try container.encodeIfPresent(yearFrom, forKey: .yearFrom)
        try container.encodeIfPresent(yearTo, forKey: .yearTo)
        try container.encode(genreQuery, forKey: .genreQuery)
        try container.encode(tagsQuery, forKey: .tagsQuery)
    }

    var jsonObject: JSONObject {
        var object: JSONObject = [
            "sourceQuery": sourceQuery,
            "yearQuery": yearQuery,
            "genreQuery": genreQuery,
            "tagsQuery": tagsQuery
        ]
        if let yearFrom {
            object["yearFrom"] = yearFrom
        }
        if let yearTo {
            object["yearTo"] = yearTo
        }
        return object
    }

    func summaryText(in mode: AppLanguageMode) -> String? {
        guard activeFilterCount > 0 else { return nil }
        let prioritizedSummaryItems = prioritizedSummaryItems(in: mode)
        if !prioritizedSummaryItems.isEmpty {
            let hiddenCount = activeFilterCount - representedSummaryItemCount
            if hiddenCount > 0 {
                let hiddenLabel = mode == .english ? "\(hiddenCount) more" : "另 \(hiddenCount) 项"
                return (prioritizedSummaryItems + [hiddenLabel]).joined(separator: " · ")
            }
            return prioritizedSummaryItems.joined(separator: " · ")
        }

        if mode == .english {
            let noun = activeFilterCount == 1 ? "filter" : "filters"
            return "\(activeFilterCount) \(noun) applied"
        }
        return "已应用 \(activeFilterCount) 个筛选条件"
    }

    func matches(_ metadata: CorpusMetadataProfile) -> Bool {
        matchesField(sourceQuery, value: metadata.sourceLabel)
            && matchesYear(metadata.yearLabel)
            && matchesField(genreQuery, value: metadata.genreLabel)
            && matchesTags(tagsQuery, tags: metadata.tags)
    }

    private var hasYearFilter: Bool {
        yearFrom != nil || yearTo != nil || !yearQuery.isEmpty
    }

    private func matchesField(_ query: String, value: String) -> Bool {
        guard !query.isEmpty else { return true }
        return value.localizedCaseInsensitiveContains(query)
    }

    private func matchesYear(_ yearLabel: String) -> Bool {
        if let bounds = normalizedYearBounds {
            let extractedYears = MetadataYearSuggestionSupport.extractYears(from: yearLabel)
            guard !extractedYears.isEmpty else { return false }
            return extractedYears.contains { year in
                if let lower = bounds.lower, year < lower {
                    return false
                }
                if let upper = bounds.upper, year > upper {
                    return false
                }
                return true
            }
        }

        guard !yearQuery.isEmpty else { return true }
        return matchesField(yearQuery, value: yearLabel)
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

    private var normalizedYearBounds: (lower: Int?, upper: Int?)? {
        let lower = yearFrom.flatMap(Self.parseSingleYear)
        let upper = yearTo.flatMap(Self.parseSingleYear)
        guard lower != nil || upper != nil else { return nil }
        return (lower, upper)
    }

    private var representedSummaryItemCount: Int {
        var count = 0
        if !sourceQuery.isEmpty { count += 1 }
        if hasYearFilter { count += 1 }
        if count > 0 {
            return count
        }
        if !genreQuery.isEmpty { count += 1 }
        if !tagsQuery.isEmpty { count += 1 }
        return count
    }

    private func prioritizedSummaryItems(in mode: AppLanguageMode) -> [String] {
        var items: [String] = []

        if !sourceQuery.isEmpty {
            items.append(mode == .english ? "Source: \(sourceQuery)" : "来源：\(sourceQuery)")
        }

        if let yearSummary = summaryYearText(in: mode) {
            items.append(yearSummary)
        }

        if items.isEmpty {
            if !genreQuery.isEmpty {
                items.append(mode == .english ? "Genre: \(genreQuery)" : "体裁：\(genreQuery)")
            }
            if !tagsQuery.isEmpty {
                items.append(mode == .english ? "Tags: \(tagsQuery)" : "标签：\(tagsQuery)")
            }
        }

        return items
    }

    private func summaryYearText(in mode: AppLanguageMode) -> String? {
        if let bounds = normalizedYearBounds {
            let yearValue: String
            switch (bounds.lower, bounds.upper) {
            case let (.some(lower), .some(upper)) where lower == upper:
                yearValue = "\(lower)"
            case let (.some(lower), .some(upper)):
                yearValue = "\(lower)-\(upper)"
            case let (.some(lower), .none):
                yearValue = "\(lower)+"
            case let (.none, .some(upper)):
                yearValue = mode == .english ? "up to \(upper)" : "至 \(upper)"
            case (.none, .none):
                return nil
            }

            return mode == .english ? "Year: \(yearValue)" : "年份：\(yearValue)"
        }

        guard !yearQuery.isEmpty else { return nil }
        return mode == .english ? "Year: \(yearQuery)" : "年份：\(yearQuery)"
    }

    private static func normalizedYearBounds(
        yearFrom: String?,
        yearTo: String?
    ) -> (from: String?, to: String?) {
        let parsedFrom = parseSingleYear(yearFrom)
        let parsedTo = parseSingleYear(yearTo)

        switch (parsedFrom, parsedTo) {
        case let (.some(from), .some(to)):
            let lower = min(from, to)
            let upper = max(from, to)
            return ("\(lower)", "\(upper)")
        case let (.some(from), .none):
            return ("\(from)", nil)
        case let (.none, .some(to)):
            return (nil, "\(to)")
        case (.none, .none):
            return (nil, nil)
        }
    }

    private static func parseSingleYear(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4,
              trimmed.allSatisfy(\.isNumber),
              let year = Int(trimmed) else {
            return nil
        }
        return year
    }

    private static func decodeYearBound(from object: JSONObject, key: String) -> String? {
        if let value = object[key] as? String {
            return value
        }
        if let value = object[key] as? Int {
            return "\(value)"
        }
        if let value = object[key] as? Double {
            return "\(Int(value))"
        }
        return nil
    }

    private static func decodeYearBound(
        from container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Int.self, forKey: key) {
            return "\(value)"
        }
        if let value = try? container.decodeIfPresent(Double.self, forKey: key) {
            return "\(Int(value))"
        }
        return nil
    }

    private enum CodingKeys: String, CodingKey {
        case sourceQuery
        case yearQuery
        case yearFrom
        case yearTo
        case genreQuery
        case tagsQuery
    }
}
