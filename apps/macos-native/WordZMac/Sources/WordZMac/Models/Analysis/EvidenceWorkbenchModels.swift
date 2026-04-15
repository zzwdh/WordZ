import Foundation

enum EvidenceSourceKind: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case kwic
    case locator

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .kwic:
            return wordZText("KWIC", "KWIC", mode: mode)
        case .locator:
            return wordZText("定位器", "Locator", mode: mode)
        }
    }
}

enum EvidenceReviewStatus: String, CaseIterable, Identifiable, Codable, Sendable, Equatable {
    case pending
    case keep
    case exclude

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .pending:
            return wordZText("待审", "Pending", mode: mode)
        case .keep:
            return wordZText("保留", "Keep", mode: mode)
        case .exclude:
            return wordZText("排除", "Exclude", mode: mode)
        }
    }
}

enum EvidenceReviewFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case pending
    case keep
    case exclude

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部", "All", mode: mode)
        case .pending:
            return wordZText("待审", "Pending", mode: mode)
        case .keep:
            return wordZText("保留", "Keep", mode: mode)
        case .exclude:
            return wordZText("排除", "Exclude", mode: mode)
        }
    }

    func includes(_ status: EvidenceReviewStatus) -> Bool {
        switch self {
        case .all:
            return true
        case .pending:
            return status == .pending
        case .keep:
            return status == .keep
        case .exclude:
            return status == .exclude
        }
    }
}

struct EvidenceItem: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let sourceKind: EvidenceSourceKind
    let savedSetID: String?
    let savedSetName: String?
    let corpusID: String
    let corpusName: String
    let sentenceId: Int
    let sentenceTokenIndex: Int?
    let leftContext: String
    let keyword: String
    let rightContext: String
    let fullSentenceText: String
    let citationText: String
    let query: String
    let leftWindow: Int
    let rightWindow: Int
    let searchOptionsSnapshot: SearchOptionsState?
    let stopwordFilterSnapshot: StopwordFilterState?
    var reviewStatus: EvidenceReviewStatus
    var note: String?
    let createdAt: String
    var updatedAt: String

    var concordanceText: String {
        [leftContext, keyword, rightContext]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var hasSavedSetProvenance: Bool {
        !(savedSetID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    func parameterSummary(in mode: AppLanguageMode) -> String {
        var parts = [
            wordZText("查询", "Query", mode: mode) + ": " + query,
            "L\(leftWindow) / R\(rightWindow)"
        ]
        if let searchOptionsSnapshot {
            parts.append(searchOptionsSnapshot.summaryText)
        }
        if let stopwordFilterSnapshot {
            parts.append(stopwordFilterSnapshot.summaryText)
        }
        return parts.joined(separator: " · ")
    }
}

struct EvidenceTransferBundle: Codable, Equatable, Sendable {
    let version: Int
    let exportedAt: String
    let items: [EvidenceItem]
}

enum EvidenceTransferSupport {
    enum TransferError: LocalizedError {
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有可导出的证据条目。", "There are no evidence items to export.", mode: .system)
            }
        }
    }

    static func makeBundle(
        items: [EvidenceItem],
        exportedAt: Date = Date()
    ) throws -> EvidenceTransferBundle {
        guard !items.isEmpty else {
            throw TransferError.emptySelection
        }
        return EvidenceTransferBundle(
            version: 1,
            exportedAt: ISO8601DateFormatter().string(from: exportedAt),
            items: items
        )
    }

    static func exportData(
        items: [EvidenceItem],
        exportedAt: Date = Date()
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(makeBundle(items: items, exportedAt: exportedAt))
    }
}

enum EvidenceMarkdownPacketSupport {
    enum PacketError: LocalizedError {
        case emptySelection

        var errorDescription: String? {
            switch self {
            case .emptySelection:
                return wordZText("没有已标记为保留的证据条目。", "There are no kept evidence items to export.", mode: .system)
            }
        }
    }

    static func document(
        items: [EvidenceItem],
        exportedAt: Date = Date()
    ) throws -> PlainTextExportDocument {
        let keptItems = items.filter { $0.reviewStatus == .keep }
        guard !keptItems.isEmpty else {
            throw PacketError.emptySelection
        }

        let exportedAtText = ISO8601DateFormatter().string(from: exportedAt)
        var lines: [String] = [
            "# " + wordZText("证据包", "Evidence Packet", mode: .system),
            "",
            wordZText("导出时间", "Exported At", mode: .system) + ": " + exportedAtText,
            wordZText("条目数", "Items", mode: .system) + ": \(keptItems.count)"
        ]

        for (index, item) in keptItems.enumerated() {
            lines.append("")
            lines.append("## \(index + 1). \(item.keyword)")
            lines.append("")
            lines.append("- " + wordZText("来源", "Source", mode: .system) + ": " + item.sourceKind.title(in: .system))
            lines.append("- " + wordZText("语料", "Corpus", mode: .system) + ": " + item.corpusName)
            lines.append("- " + wordZText("句号", "Sentence", mode: .system) + ": \(item.sentenceId + 1)")
            lines.append("- " + wordZText("参数", "Parameters", mode: .system) + ": " + item.parameterSummary(in: .system))
            if let savedSetName = normalizedValue(item.savedSetName) {
                lines.append("- " + wordZText("命中集", "Hit Set", mode: .system) + ": " + savedSetName)
            }
            lines.append("")
            lines.append("### " + wordZText("索引行", "Concordance", mode: .system))
            lines.append(item.concordanceText)
            lines.append("")
            lines.append("### " + wordZText("完整句", "Full Sentence", mode: .system))
            lines.append(item.fullSentenceText)
            lines.append("")
            lines.append("### " + wordZText("引文", "Citation", mode: .system))
            lines.append(item.citationText)
            if let note = normalizedValue(item.note) {
                lines.append("")
                lines.append("### " + wordZText("备注", "Note", mode: .system))
                lines.append(note)
            }
        }

        return PlainTextExportDocument(
            suggestedName: "evidence-packet.md",
            text: lines.joined(separator: "\n"),
            allowedExtension: "md"
        )
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
