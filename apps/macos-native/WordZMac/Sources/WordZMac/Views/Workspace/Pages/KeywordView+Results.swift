import SwiftUI

extension KeywordView {
    @ViewBuilder
    var keywordResultsSection: some View {
        if let scene = viewModel.scene {
            keywordResultsContent(scene)
        } else {
            keywordEmptyState
        }
    }

    @ViewBuilder
    func keywordResultsContent(_ scene: KeywordSceneModel) -> some View {
        keywordResultsSummaryCard(scene)
        keywordResultsMethodCard(scene)
        keywordResultsTableSection(scene)

        if viewModel.activeTab == .lists {
            if let selectedRow = viewModel.selectedSceneRow {
                keywordListSelectedRowSection(selectedRow)
            }
        } else if let selectedRow = viewModel.selectedSceneRow,
                  let rawRow = viewModel.selectedKeywordRow {
            keywordSelectedRowSection(selectedRow, rawRow: rawRow)
        }
    }
}
