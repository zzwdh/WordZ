import Foundation

enum ConcordanceSavedSetKind: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case kwic
    case locator

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .kwic:
            return wordZText("KWIC 命中集", "KWIC Hit Set", mode: mode)
        case .locator:
            return wordZText("Locator 命中集", "Locator Hit Set", mode: mode)
        }
    }
}

struct ConcordanceSavedSetRow: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let sentenceId: Int
    let sentenceTokenIndex: Int?
    let status: String
    let leftContext: String
    let keyword: String
    let rightContext: String
    let concordanceText: String
    let citationText: String
    let fullSentenceText: String
}

struct ConcordanceSavedSet: Identifiable, Equatable, Codable, Sendable {
    let id: String
    var name: String
    let kind: ConcordanceSavedSetKind
    let corpusID: String
    let corpusName: String
    let query: String
    let sourceSentenceId: Int?
    let leftWindow: Int
    let rightWindow: Int
    let searchOptions: SearchOptionsState?
    let stopwordFilter: StopwordFilterState?
    let createdAt: String
    var updatedAt: String
    var notes: String? = nil
    let rows: [ConcordanceSavedSetRow]

    var rowCount: Int { rows.count }
}

struct ConcordanceSavedSetTransferBundle: Codable, Equatable, Sendable {
    let version: Int
    let exportedAt: String
    let sets: [ConcordanceSavedSet]
}

enum ConcordanceSavedSetTransferSupport {
    enum TransferError: LocalizedError {
        case emptySelection
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有可导出的命中集。", "No hit sets are available for export.", mode: .system)
            case .invalidPayload:
                return wordZText("无法识别命中集 JSON。", "The hit set JSON payload is invalid.", mode: .system)
            }
        }
    }

    static func makeBundle(
        sets: [ConcordanceSavedSet],
        exportedAt: Date = Date()
    ) throws -> ConcordanceSavedSetTransferBundle {
        guard !sets.isEmpty else {
            throw TransferError.emptySelection
        }
        return ConcordanceSavedSetTransferBundle(
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: exportedAt),
            sets: sets
        )
    }

    static func exportData(
        sets: [ConcordanceSavedSet],
        exportedAt: Date = Date()
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makeBundle(sets: sets, exportedAt: exportedAt))
    }

    static func importedSets(
        from data: Data,
        existingSets: [ConcordanceSavedSet],
        importedAt: Date = Date()
    ) throws -> [ConcordanceSavedSet] {
        let decoder = JSONDecoder()
        let bundle: ConcordanceSavedSetTransferBundle
        if let decodedBundle = try? decoder.decode(ConcordanceSavedSetTransferBundle.self, from: data) {
            bundle = decodedBundle
        } else if let decodedSets = try? decoder.decode([ConcordanceSavedSet].self, from: data) {
            bundle = ConcordanceSavedSetTransferBundle(version: 1, exportedAt: "", sets: decodedSets)
        } else {
            throw TransferError.invalidPayload
        }

        return sanitizedImportedSets(
            bundle.sets,
            existingSets: existingSets,
            importedAt: importedAt
        )
    }

    private static func sanitizedImportedSets(
        _ sets: [ConcordanceSavedSet],
        existingSets: [ConcordanceSavedSet],
        importedAt: Date
    ) -> [ConcordanceSavedSet] {
        let importedAtText = ISO8601DateFormatter().string(from: importedAt)
        var usedIDs = Set(existingSets.map(\.id))
        var usedNameKeys = Set(existingSets.map { nameKey(kind: $0.kind, name: $0.name) })

        return sets.map { set in
            let trimmedID = set.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedID: String
            if trimmedID.isEmpty || usedIDs.contains(trimmedID) {
                resolvedID = UUID().uuidString
            } else {
                resolvedID = trimmedID
            }
            usedIDs.insert(resolvedID)

            let trimmedName = set.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let baseName = trimmedName.isEmpty ? defaultImportedName(for: set.kind) : trimmedName
            let resolvedName = uniqueImportedName(
                baseName: baseName,
                kind: set.kind,
                usedNameKeys: &usedNameKeys
            )

            return ConcordanceSavedSet(
                id: resolvedID,
                name: resolvedName,
                kind: set.kind,
                corpusID: set.corpusID,
                corpusName: set.corpusName,
                query: set.query,
                sourceSentenceId: set.sourceSentenceId,
                leftWindow: set.leftWindow,
                rightWindow: set.rightWindow,
                searchOptions: set.searchOptions,
                stopwordFilter: set.stopwordFilter,
                createdAt: set.createdAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? importedAtText : set.createdAt,
                updatedAt: set.updatedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? importedAtText : set.updatedAt,
                notes: normalizedNotes(set.notes),
                rows: set.rows
            )
        }
    }

    private static func uniqueImportedName(
        baseName: String,
        kind: ConcordanceSavedSetKind,
        usedNameKeys: inout Set<String>
    ) -> String {
        let suffix = wordZText("导入", "Imported", mode: .system)
        let candidates = sequence(first: baseName) { previous in
            let prefix = baseName + " · " + suffix
            if previous == baseName {
                return prefix
            }
            if previous == prefix {
                return prefix + " 2"
            }
            let components = previous.split(separator: " ")
            if let last = components.last, let index = Int(last) {
                return prefix + " \(index + 1)"
            }
            return prefix + " 2"
        }

        for candidate in candidates {
            let key = nameKey(kind: kind, name: candidate)
            if !usedNameKeys.contains(key) {
                usedNameKeys.insert(key)
                return candidate
            }
        }

        return baseName
    }

    private static func defaultImportedName(for kind: ConcordanceSavedSetKind) -> String {
        switch kind {
        case .kwic:
            return wordZText("导入 KWIC 命中集", "Imported KWIC Hit Set", mode: .system)
        case .locator:
            return wordZText("导入 Locator 命中集", "Imported Locator Hit Set", mode: .system)
        }
    }

    private static func nameKey(kind: ConcordanceSavedSetKind, name: String) -> String {
        "\(kind.rawValue)::\(name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func normalizedNotes(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension ConcordanceSavedSet {
    func filteredRows(matching query: String) -> [ConcordanceSavedSetRow] {
        let terms = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return rows }
        return rows.filter { row in
            row.matchesAllTerms(terms)
        }
    }
}

extension ConcordanceSavedSetRow {
    fileprivate func matchesAllTerms(_ terms: [String]) -> Bool {
        let haystack = [
            leftContext,
            keyword,
            rightContext,
            concordanceText,
            citationText,
            fullSentenceText,
            status
        ]
        .joined(separator: "\n")
        .lowercased()
        return terms.allSatisfy { haystack.contains($0) }
    }
}
