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
    case custom(NativeTableCustomColumnPresentation)
}

enum NativeTableCustomColumnPresentation: Equatable, Sendable {
    case markerStrip
}

enum NativeTableSortDirection: Equatable, Sendable {
    case ascending
    case descending

    var indicator: String {
        switch self {
        case .ascending:
            return "↑"
        case .descending:
            return "↓"
        }
    }

    var isAscending: Bool {
        self == .ascending
    }

    init?(indicator: String?) {
        switch indicator {
        case "↑":
            self = .ascending
        case "↓":
            self = .descending
        default:
            return nil
        }
    }
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
    let sortDirection: NativeTableSortDirection?
    let presentation: NativeTableColumnPresentation
    let widthPolicy: NativeTableColumnWidthPolicy
    let isPinned: Bool

    init(
        id: String,
        title: String,
        isVisible: Bool,
        sortIndicator: String?,
        sortDirection: NativeTableSortDirection? = nil,
        presentation: NativeTableColumnPresentation = .label,
        widthPolicy: NativeTableColumnWidthPolicy = .standard,
        isPinned: Bool = false
    ) {
        self.id = id
        self.title = title
        self.isVisible = isVisible
        self.sortDirection = sortDirection ?? NativeTableSortDirection(indicator: sortIndicator)
        self.sortIndicator = sortIndicator ?? self.sortDirection?.indicator
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

enum NativeTableCellValue: Equatable, Sendable {
    case text(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)
    case custom(text: String, presentation: NativeTableCustomCellValue)

    var stringValue: String {
        switch self {
        case .text(let value):
            return value
        case .integer(let value):
            return String(value)
        case .decimal(let value):
            return String(value)
        case .boolean(let value):
            return value ? "true" : "false"
        case .custom(let text, _):
            return text
        }
    }
}

enum NativeTableCustomCellValue: Equatable, Sendable {
    case markerStrip([NativeTableMarkerValue])
}

struct NativeTableMarkerValue: Identifiable, Equatable, Sendable {
    let id: String
    let normalizedPosition: Double
    let accessibilityLabel: String

    init(
        id: String,
        normalizedPosition: Double,
        accessibilityLabel: String
    ) {
        self.id = id
        self.normalizedPosition = min(max(normalizedPosition, 0), 1)
        self.accessibilityLabel = accessibilityLabel
    }
}

struct NativeTableColumnSpec<ColumnKey>: Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    let descriptor: NativeTableColumnDescriptor

    init(
        _ key: ColumnKey,
        title: String,
        isVisible: Bool,
        sortDirection: NativeTableSortDirection? = nil,
        presentation: NativeTableColumnPresentation = .label,
        widthPolicy: NativeTableColumnWidthPolicy = .standard,
        isPinned: Bool = false
    ) {
        self.descriptor = NativeTableColumnDescriptor(
            id: key.rawValue,
            title: title,
            isVisible: isVisible,
            sortIndicator: nil,
            sortDirection: sortDirection,
            presentation: presentation,
            widthPolicy: widthPolicy,
            isPinned: isPinned
        )
    }

    init(descriptor: NativeTableColumnDescriptor) {
        self.descriptor = descriptor
    }
}

@resultBuilder
enum NativeTableColumnBuilder<ColumnKey>
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    static func buildExpression(_ expression: NativeTableColumnSpec<ColumnKey>) -> [NativeTableColumnSpec<ColumnKey>] {
        [expression]
    }

    static func buildExpression(_ expression: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        expression
    }

    static func buildBlock(_ components: [NativeTableColumnSpec<ColumnKey>]...) -> [NativeTableColumnSpec<ColumnKey>] {
        components.flatMap { $0 }
    }

    static func buildArray(_ components: [[NativeTableColumnSpec<ColumnKey>]]) -> [NativeTableColumnSpec<ColumnKey>] {
        components.flatMap { $0 }
    }

    static func buildOptional(_ component: [NativeTableColumnSpec<ColumnKey>]?) -> [NativeTableColumnSpec<ColumnKey>] {
        component ?? []
    }

    static func buildEither(first component: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        component
    }

    static func buildEither(second component: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        component
    }
}

struct NativeTableCell<ColumnKey>: Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    let columnID: String
    let value: NativeTableCellValue

    init(_ key: ColumnKey, _ value: String) {
        self.columnID = key.rawValue
        self.value = .text(value)
    }

    init(_ key: ColumnKey, value: NativeTableCellValue) {
        self.columnID = key.rawValue
        self.value = value
    }
}

struct NativeTableTypedRowDescriptor<ColumnKey>: Identifiable, Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    let id: String
    let cells: [NativeTableCell<ColumnKey>]

    init(
        id: String,
        columnKey: ColumnKey.Type = ColumnKey.self,
        @NativeTableRowBuilder<ColumnKey> cells: () -> [NativeTableCell<ColumnKey>]
    ) {
        self.id = id
        let resolvedCells = cells()
        let duplicateColumnIDs = NativeTableRowDescriptor.duplicateColumnIDs(in: resolvedCells)
        precondition(
            duplicateColumnIDs.isEmpty,
            "Duplicate NativeTableCell column IDs in typed row '\(id)': \(duplicateColumnIDs.joined(separator: ", "))"
        )
        self.cells = resolvedCells
    }

    var erased: NativeTableRowDescriptor {
        NativeTableRowDescriptor(self)
    }

    func value(for key: ColumnKey) -> String {
        cell(for: key)?.stringValue ?? ""
    }

    func cell(for key: ColumnKey) -> NativeTableCellValue? {
        cells.first(where: { $0.columnID == key.rawValue })?.value
    }
}

@resultBuilder
enum NativeTableRowBuilder<ColumnKey>
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    static func buildExpression(_ expression: NativeTableCell<ColumnKey>) -> [NativeTableCell<ColumnKey>] {
        [expression]
    }

    static func buildExpression(_ expression: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        expression
    }

    static func buildBlock(_ components: [NativeTableCell<ColumnKey>]...) -> [NativeTableCell<ColumnKey>] {
        components.flatMap { $0 }
    }

    static func buildArray(_ components: [[NativeTableCell<ColumnKey>]]) -> [NativeTableCell<ColumnKey>] {
        components.flatMap { $0 }
    }

    static func buildOptional(_ component: [NativeTableCell<ColumnKey>]?) -> [NativeTableCell<ColumnKey>] {
        component ?? []
    }

    static func buildEither(first component: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        component
    }

    static func buildEither(second component: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        component
    }
}

struct NativeTableRowDescriptor: Identifiable, Equatable, Sendable {
    let id: String
    let cells: [String: NativeTableCellValue]

    init(id: String, values: [String: String]) {
        self.id = id
        self.cells = values.mapValues { .text($0) }
    }

    init(id: String, cells: [String: NativeTableCellValue]) {
        self.id = id
        self.cells = cells
    }

    init<ColumnKey>(
        id: String,
        columnKey: ColumnKey.Type = ColumnKey.self,
        @NativeTableRowBuilder<ColumnKey> cells: () -> [NativeTableCell<ColumnKey>]
    ) where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
        self.init(
            NativeTableTypedRowDescriptor(
                id: id,
                columnKey: columnKey,
                cells: cells
            )
        )
    }

    init<ColumnKey>(
        _ typedRow: NativeTableTypedRowDescriptor<ColumnKey>
    ) where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
        self.id = typedRow.id
        var keyedCells: [String: NativeTableCellValue] = [:]
        for cell in typedRow.cells {
            keyedCells[cell.columnID] = cell.value
        }
        self.cells = keyedCells
    }

    static func duplicateColumnIDs<ColumnKey>(
        in cells: [NativeTableCell<ColumnKey>]
    ) -> [String] where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
        var seen: Set<String> = []
        var duplicates: [String] = []
        var emittedDuplicates: Set<String> = []

        for cell in cells {
            if seen.contains(cell.columnID), !emittedDuplicates.contains(cell.columnID) {
                duplicates.append(cell.columnID)
                emittedDuplicates.insert(cell.columnID)
            } else {
                seen.insert(cell.columnID)
            }
        }

        return duplicates
    }

    var values: [String: String] {
        cells.mapValues(\.stringValue)
    }

    func value(for columnID: String) -> String {
        cells[columnID]?.stringValue ?? ""
    }

    func cell(for columnID: String) -> NativeTableCellValue? {
        cells[columnID]
    }

    func value<ColumnKey>(for key: ColumnKey) -> String where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        value(for: key.rawValue)
    }

    func cell<ColumnKey>(for key: ColumnKey) -> NativeTableCellValue? where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        cell(for: key.rawValue)
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

    init<ColumnKey>(
        storageKey: String? = nil,
        columnKey: ColumnKey.Type = ColumnKey.self,
        defaultDensity: NativeTableDensityPreset = .standard,
        @NativeTableColumnBuilder<ColumnKey> columns: () -> [NativeTableColumnSpec<ColumnKey>]
    ) where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
        self.init(
            storageKey: storageKey,
            columns: columns().map(\.descriptor),
            defaultDensity: defaultDensity
        )
    }

    static let empty = NativeTableDescriptor(storageKey: "empty", columns: [])

    func column(id: String) -> NativeTableColumnDescriptor? {
        columns.first(where: { $0.id == id })
    }

    func column<ColumnKey>(for key: ColumnKey) -> NativeTableColumnDescriptor? where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        column(id: key.rawValue)
    }

    func isVisible(_ id: String) -> Bool {
        column(id: id)?.isVisible ?? false
    }

    func isVisible<ColumnKey>(_ key: ColumnKey) -> Bool where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        isVisible(key.rawValue)
    }

    var visibleColumns: [NativeTableColumnDescriptor] {
        columns.filter(\.isVisible)
    }

    func displayTitle(for id: String, fallback: String) -> String {
        guard let column = column(id: id) else { return fallback }
        guard let indicator = column.sortIndicator else { return column.title }
        return "\(column.title) \(indicator)"
    }

    func displayTitle<ColumnKey>(for key: ColumnKey, fallback: String) -> String where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        displayTitle(for: key.rawValue, fallback: fallback)
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
