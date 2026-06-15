import Foundation

package enum NativeTableDensityPreset: String, CaseIterable, Equatable, Sendable {
    case compact
    case standard
    case reading
}

package enum NativeTableColumnPresentation: Equatable, Sendable {
    case label
    case numeric(precision: Int? = nil, usesGrouping: Bool = true)
    case keyword
    case contextLeading
    case contextTrailing
    case contextCenter
    case summary
    case custom(NativeTableCustomColumnPresentation)
}

package enum NativeTableCustomColumnPresentation: Equatable, Sendable {
    case markerStrip
}

package enum NativeTableSortDirection: Equatable, Sendable {
    case ascending
    case descending

    package var indicator: String {
        switch self {
        case .ascending:
            return "↑"
        case .descending:
            return "↓"
        }
    }

    package var isAscending: Bool {
        self == .ascending
    }

    package init?(indicator: String?) {
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

package enum NativeTableColumnWidthPolicy: String, Equatable, Sendable {
    case compact
    case numeric
    case standard
    case keyword
    case context
    case summary
}

package struct NativeTableColumnDescriptor: Identifiable, Equatable, Sendable {
    package let id: String
    package let title: String
    package let isVisible: Bool
    package let sortIndicator: String?
    package let sortDirection: NativeTableSortDirection?
    package let presentation: NativeTableColumnPresentation
    package let widthPolicy: NativeTableColumnWidthPolicy
    package let isPinned: Bool

    package init(
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

    package var isNumeric: Bool {
        if case .numeric = presentation {
            return true
        }
        return false
    }
}

package enum NativeTableCellValue: Equatable, Sendable {
    case text(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)
    case custom(text: String, presentation: NativeTableCustomCellValue)

    package var stringValue: String {
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

package enum NativeTableCustomCellValue: Equatable, Sendable {
    case markerStrip([NativeTableMarkerValue])
}

package struct NativeTableMarkerValue: Identifiable, Equatable, Sendable {
    package let id: String
    package let normalizedPosition: Double
    package let accessibilityLabel: String

    package init(
        id: String,
        normalizedPosition: Double,
        accessibilityLabel: String
    ) {
        self.id = id
        self.normalizedPosition = min(max(normalizedPosition, 0), 1)
        self.accessibilityLabel = accessibilityLabel
    }
}

package struct NativeTableColumnSpec<ColumnKey>: Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    package let descriptor: NativeTableColumnDescriptor

    package init(
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

    package init(descriptor: NativeTableColumnDescriptor) {
        self.descriptor = descriptor
    }
}

@resultBuilder
package enum NativeTableColumnBuilder<ColumnKey>
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    package static func buildExpression(_ expression: NativeTableColumnSpec<ColumnKey>) -> [NativeTableColumnSpec<ColumnKey>] {
        [expression]
    }

    package static func buildExpression(_ expression: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        expression
    }

    package static func buildBlock(_ components: [NativeTableColumnSpec<ColumnKey>]...) -> [NativeTableColumnSpec<ColumnKey>] {
        components.flatMap { $0 }
    }

    package static func buildArray(_ components: [[NativeTableColumnSpec<ColumnKey>]]) -> [NativeTableColumnSpec<ColumnKey>] {
        components.flatMap { $0 }
    }

    package static func buildOptional(_ component: [NativeTableColumnSpec<ColumnKey>]?) -> [NativeTableColumnSpec<ColumnKey>] {
        component ?? []
    }

    package static func buildEither(first component: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        component
    }

    package static func buildEither(second component: [NativeTableColumnSpec<ColumnKey>]) -> [NativeTableColumnSpec<ColumnKey>] {
        component
    }
}

package struct NativeTableCell<ColumnKey>: Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    package let columnID: String
    package let value: NativeTableCellValue

    package init(_ key: ColumnKey, _ value: String) {
        self.columnID = key.rawValue
        self.value = .text(value)
    }

    package init(_ key: ColumnKey, value: NativeTableCellValue) {
        self.columnID = key.rawValue
        self.value = value
    }
}

package struct NativeTableTypedRowDescriptor<ColumnKey>: Identifiable, Equatable, Sendable
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    package let id: String
    package let cells: [NativeTableCell<ColumnKey>]

    package init(
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

    package var erased: NativeTableRowDescriptor {
        NativeTableRowDescriptor(self)
    }

    package func value(for key: ColumnKey) -> String {
        cell(for: key)?.stringValue ?? ""
    }

    package func cell(for key: ColumnKey) -> NativeTableCellValue? {
        cells.first(where: { $0.columnID == key.rawValue })?.value
    }
}

@resultBuilder
package enum NativeTableRowBuilder<ColumnKey>
where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
    package static func buildExpression(_ expression: NativeTableCell<ColumnKey>) -> [NativeTableCell<ColumnKey>] {
        [expression]
    }

    package static func buildExpression(_ expression: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        expression
    }

    package static func buildBlock(_ components: [NativeTableCell<ColumnKey>]...) -> [NativeTableCell<ColumnKey>] {
        components.flatMap { $0 }
    }

    package static func buildArray(_ components: [[NativeTableCell<ColumnKey>]]) -> [NativeTableCell<ColumnKey>] {
        components.flatMap { $0 }
    }

    package static func buildOptional(_ component: [NativeTableCell<ColumnKey>]?) -> [NativeTableCell<ColumnKey>] {
        component ?? []
    }

    package static func buildEither(first component: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        component
    }

    package static func buildEither(second component: [NativeTableCell<ColumnKey>]) -> [NativeTableCell<ColumnKey>] {
        component
    }
}

package struct NativeTableRowDescriptor: Identifiable, Equatable, Sendable {
    package let id: String
    package let cells: [String: NativeTableCellValue]

    package init(id: String, values: [String: String]) {
        self.id = id
        self.cells = values.mapValues { .text($0) }
    }

    package init(id: String, cells: [String: NativeTableCellValue]) {
        self.id = id
        self.cells = cells
    }

    package init<ColumnKey>(
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

    package init<ColumnKey>(
        _ typedRow: NativeTableTypedRowDescriptor<ColumnKey>
    ) where ColumnKey: RawRepresentable & Sendable, ColumnKey.RawValue == String {
        self.id = typedRow.id
        var keyedCells: [String: NativeTableCellValue] = [:]
        for cell in typedRow.cells {
            keyedCells[cell.columnID] = cell.value
        }
        self.cells = keyedCells
    }

    package static func duplicateColumnIDs<ColumnKey>(
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

    package var values: [String: String] {
        cells.mapValues(\.stringValue)
    }

    package func value(for columnID: String) -> String {
        cells[columnID]?.stringValue ?? ""
    }

    package func cell(for columnID: String) -> NativeTableCellValue? {
        cells[columnID]
    }

    package func value<ColumnKey>(for key: ColumnKey) -> String where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        value(for: key.rawValue)
    }

    package func cell<ColumnKey>(for key: ColumnKey) -> NativeTableCellValue? where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        cell(for: key.rawValue)
    }
}

package struct NativeTableExportSnapshot: Equatable, Sendable {
    package let suggestedBaseName: String
    package let table: NativeTableDescriptor
    package let rows: [NativeTableRowDescriptor]
    package let metadataLines: [String]

    package init(
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

package struct NativeTableDescriptor: Equatable, Sendable {
    package let storageKey: String
    package let columns: [NativeTableColumnDescriptor]
    package let visibleColumns: [NativeTableColumnDescriptor]
    package let defaultDensity: NativeTableDensityPreset
    private let columnsByID: [String: NativeTableColumnDescriptor]

    package init(
        storageKey: String? = nil,
        columns: [NativeTableColumnDescriptor],
        defaultDensity: NativeTableDensityPreset = .standard
    ) {
        self.columns = columns
        self.visibleColumns = columns.filter(\.isVisible)
        self.storageKey = storageKey ?? columns.map(\.id).joined(separator: "|")
        self.defaultDensity = defaultDensity
        self.columnsByID = Self.firstColumnByID(columns)
    }

    package init<ColumnKey>(
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

    package static let empty = NativeTableDescriptor(storageKey: "empty", columns: [])

    package func column(id: String) -> NativeTableColumnDescriptor? {
        columnsByID[id]
    }

    package func column<ColumnKey>(for key: ColumnKey) -> NativeTableColumnDescriptor? where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        column(id: key.rawValue)
    }

    package func isVisible(_ id: String) -> Bool {
        column(id: id)?.isVisible ?? false
    }

    package func isVisible<ColumnKey>(_ key: ColumnKey) -> Bool where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        isVisible(key.rawValue)
    }

    package func displayTitle(for id: String, fallback: String) -> String {
        guard let column = column(id: id) else { return fallback }
        guard let indicator = column.sortIndicator else { return column.title }
        return "\(column.title) \(indicator)"
    }

    package func displayTitle<ColumnKey>(for key: ColumnKey, fallback: String) -> String where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        displayTitle(for: key.rawValue, fallback: fallback)
    }

    package func csvHeaderRow() -> [String] {
        visibleColumns.map(\.title)
    }

    package func csvRows(from rows: [NativeTableRowDescriptor]) -> [[String]] {
        let visible = visibleColumns
        return rows.map { row in
            visible.map { column in
                row.value(for: column.id)
            }
        }
    }

    private static func firstColumnByID(_ columns: [NativeTableColumnDescriptor]) -> [String: NativeTableColumnDescriptor] {
        var columnsByID: [String: NativeTableColumnDescriptor] = [:]
        for column in columns where columnsByID[column.id] == nil {
            columnsByID[column.id] = column
        }
        return columnsByID
    }
}
