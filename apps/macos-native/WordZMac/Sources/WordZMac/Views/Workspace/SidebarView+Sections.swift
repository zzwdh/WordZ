import SwiftUI

extension SidebarView {
    @ViewBuilder
    var sidebarSections: some View {
        analysisSection
    }

    var analysisSection: some View {
        Section(wordZText("分析导航", "Analysis", mode: languageMode)) {
            ForEach(viewModel.scene.analysisViews) { item in
                Button {
                    guard item.isEnabled else { return }
                    openAnalysis(item.tab)
                } label: {
                    sidebarAnalysisRow(item)
                }
                .buttonStyle(.plain)
                .disabled(!item.isEnabled)
            }
        }
    }
}
