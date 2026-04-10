enum TableExportFormat: String, CaseIterable {
    case xlsx
    case csv

    var allowedExtension: String {
        switch self {
        case .xlsx:
            return "xlsx"
        case .csv:
            return "csv"
        }
    }
}
