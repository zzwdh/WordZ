import Foundation

@MainActor
protocol AnalysisSelectedRowControlling: AnyObject {
    var selectedRowID: String? { get set }
}

@MainActor
extension AnalysisSelectedRowControlling {
    func syncSelectedRow<Row: Identifiable>(within rows: [Row]) where Row.ID == String {
        guard !rows.isEmpty else {
            selectedRowID = nil
            return
        }

        if let selectedRowID, rows.contains(where: { $0.id == selectedRowID }) {
            self.selectedRowID = selectedRowID
            return
        }

        selectedRowID = rows.first?.id
    }
}
