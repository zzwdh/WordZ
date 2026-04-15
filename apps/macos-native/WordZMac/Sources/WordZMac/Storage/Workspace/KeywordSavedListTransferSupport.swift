import Foundation

struct KeywordSavedListTransferBundle: Codable, Equatable, Sendable {
    let version: Int
    let exportedAt: String
    let lists: [KeywordSavedList]
}

enum KeywordSavedListTransferSupport {
    enum TransferError: LocalizedError {
        case emptySelection
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有可导出的关键词词表。", "No keyword lists are available for export.", mode: .system)
            case .invalidPayload:
                return wordZText("无法识别关键词词表 JSON。", "The keyword list JSON payload is invalid.", mode: .system)
            }
        }
    }

    static func makeBundle(
        lists: [KeywordSavedList],
        exportedAt: Date = Date()
    ) throws -> KeywordSavedListTransferBundle {
        guard !lists.isEmpty else {
            throw TransferError.emptySelection
        }
        return KeywordSavedListTransferBundle(
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: exportedAt),
            lists: lists
        )
    }

    static func exportData(
        lists: [KeywordSavedList],
        exportedAt: Date = Date()
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makeBundle(lists: lists, exportedAt: exportedAt))
    }

    static func importedLists(
        from data: Data,
        existingLists: [KeywordSavedList],
        importedAt: Date = Date()
    ) throws -> [KeywordSavedList] {
        let decoder = JSONDecoder()
        let bundle: KeywordSavedListTransferBundle
        if let decodedBundle = try? decoder.decode(KeywordSavedListTransferBundle.self, from: data) {
            bundle = decodedBundle
        } else if let decodedLists = try? decoder.decode([KeywordSavedList].self, from: data) {
            bundle = KeywordSavedListTransferBundle(version: 1, exportedAt: "", lists: decodedLists)
        } else {
            throw TransferError.invalidPayload
        }

        return sanitizedImportedLists(
            bundle.lists,
            existingIDs: Set(existingLists.map(\.id)),
            importedAt: importedAt
        )
    }

    private static func sanitizedImportedLists(
        _ lists: [KeywordSavedList],
        existingIDs: Set<String>,
        importedAt: Date
    ) -> [KeywordSavedList] {
        let importedAtText = ISO8601DateFormatter().string(from: importedAt)
        var usedIDs = existingIDs

        return lists.map { list in
            let sanitizedName = list.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? wordZText("导入词表", "Imported List", mode: .system)
                : list.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredID = list.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let resolvedID: String
            if preferredID.isEmpty || usedIDs.contains(preferredID) {
                resolvedID = UUID().uuidString
            } else {
                resolvedID = preferredID
            }
            usedIDs.insert(resolvedID)

            return KeywordSavedList(
                id: resolvedID,
                name: sanitizedName,
                group: list.group,
                createdAt: list.createdAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? importedAtText : list.createdAt,
                updatedAt: list.updatedAt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? importedAtText : list.updatedAt,
                focusLabel: list.focusLabel,
                referenceLabel: list.referenceLabel,
                configuration: list.configuration,
                rows: list.rows
            )
        }
    }
}
