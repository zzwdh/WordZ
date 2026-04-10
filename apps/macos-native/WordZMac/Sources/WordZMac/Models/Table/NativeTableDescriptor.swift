import Foundation

enum NativeTableDensityPreset: String, CaseIterable, Equatable, Sendable {
    case compact
    case standard
    case reading

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .compact:
            return wordZText("紧凑", "Compact", mode: mode)
        case .standard:
            return wordZText("标准", "Standard", mode: mode)
        case .reading:
            return wordZText("阅读", "Reading", mode: mode)
        }
    }
}

enum NativeTableColumnPresentation: Equatable, Sendable {
    case label
    case numeric(precision: Int? = nil, usesGrouping: Bool = true)
    case keyword
    case contextLeading
    case contextTrailing
    case contextCenter
    case summary
}

enum NativeTableColumnWidthPolicy: String, Equatable, Sendable {
    case compact
    case numeric
    case standard
    case keyword
    case context
    case summary
}

struct NativeTableColumnDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let isVisible: Bool
    let sortIndicator: String?
    let presentation: NativeTableColumnPresentation
    let widthPolicy: NativeTableColumnWidthPolicy
    let isPinned: Bool

    init(
        id: String,
        title: String,
        isVisible: Bool,
        sortIndicator: String?,
        presentation: NativeTableColumnPresentation = .label,
        widthPolicy: NativeTableColumnWidthPolicy = .standard,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isVisible = isVisible
        self.sortIndicator = sortIndicator
        self.presentation = presentation
        self.widthPolicy = widthPolicy
        self.isPinned = isPinned
    }

    var isNumeric: Bool {
        if case .numeric = presentation {
            return true
        }
        return false
    }
}

struct NativeTableRowDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let values: [String: String]

    func value(for columnID: String) -> String {
        values[columnID] ?? ""
    }
}

struct NativeTableExportSnapshot: Equatable, Sendable {
    let suggestedBaseName: String
    let table: NativeTableDescriptor
    let rows: [NativeTableRowDescriptor]
    let metadataLines: [String]

    init(
        suggestedBaseName: String,
        table: NativeTableDescriptor,
        rows: [NativeTableRowDescriptor],
        metadataLines: [String] = []
    ) {
        self.suggestedBaseName = suggestedBaseName
        self.table = table
        self.rows = rows
        self.metadataLines = metadataLines
    }
}

struct NativeTableDescriptor: Equatable, Sendable {
    let storageKey: String
    let columns: [NativeTableColumnDescriptor]
    let defaultDensity: NativeTableDensityPreset

    init(
        storageKey: String? = nil,
        columns: [NativeTableColumnDescriptor],
        defaultDensity: NativeTableDensityPreset = .standard
    ) {
        self.columns = columns
        self.storageKey = storageKey ?? columns.map(\.id).joined(separator: "|")
        self.defaultDensity = defaultDensity
    }

    static let empty = NativeTableDescriptor(storageKey: "empty", columns: [])

    func column(id: String) -> NativeTableColumnDescriptor? {
        columns.first(where: { $0.id == id })
    }

    func isVisible(_ id: String) -> Bool {
        column(id: id)?.isVisible ?? false
    }

    var visibleColumns: [NativeTableColumnDescriptor] {
        columns.filter(\.isVisible)
    }

    func displayTitle(for id: String, fallback: String) -> String {
        guard let column = column(id: id) else { return fallback }
        guard let indicator = column.sortIndicator else { return column.title }
        return "\(column.title) \(indicator)"
    }

    func csvHeaderRow() -> [String] {
        visibleColumns.map(\.title)
    }

    func csvRows(from rows: [NativeTableRowDescriptor]) -> [[String]] {
        let visible = visibleColumns
        return rows.map { row in
            visible.map { column in
                row.value(for: column.id)
            }
        }
    }
}
