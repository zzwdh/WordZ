import SwiftUI

struct EvidenceWorkbenchDetailPanel: View {
    @ObservedObject var workbench: EvidenceWorkbenchViewModel
    @State private var showsExportOptions = false
    @State private var showsSourceTrace = false

    let onAction: (EvidenceWorkbenchWindowAction) -> Void

    var body: some View {
        if let item = workbench.selectedItem {
            EvidenceWorkbenchSelectedItemDetail(
                workbench: workbench,
                item: item,
                showsExportOptions: $showsExportOptions,
                showsSourceTrace: $showsSourceTrace,
                onAction: onAction
            )
        } else {
            EvidenceWorkbenchDetailEmptyState()
        }
    }
}
