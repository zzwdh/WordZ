import Foundation

struct NativeTableColumnDescriptor: Identifiable, Equatable {
    let id: String
    let title: String
    let isVisible: Bool
    let sortIndicator: String?
}

struct NativeTableRowDescriptor: Identifiable, Equatable {
    let id: String
    let values: [String: String]

    func value(for columnID: String) -> String {
        values[columnID] ?? ""
    }
}

struct NativeTableExportSnapshot: Equatable {
    let suggestedBaseName: String
    let table: NativeTableDescriptor
    let rows: [NativeTableRowDescriptor]
}

struct NativeTableDescriptor: Equatable {
    let storageKey: String
    let columns: [NativeTableColumnDescriptor]

    init(storageKey: String? = nil, columns: [NativeTableColumnDescriptor]) {
        self.columns = columns
        self.storageKey = storageKey ?? columns.map(\.id).joined(separator: "|")
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
