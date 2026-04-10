import SwiftUI

extension SidebarView {
    @ViewBuilder
    var sidebarSections: some View {
        workspaceSection
        analysisSection
        currentCorpusSection
    }

    var workspaceSection: some View {
        Section(wordZText("工作区", "Workspace", mode: languageMode)) {
            sidebarOverviewRow(
                title: viewModel.scene.currentCorpus?.title ?? viewModel.scene.appName,
                detail: viewModel.scene.currentCorpus?.subtitle ?? viewModel.scene.versionLabel,
                symbol: viewModel.scene.currentCorpus == nil ? "books.vertical" : "doc.text"
            )
        }
    }

    var analysisSection: some View {
        Section(wordZText("分析导航", "Analysis", mode: languageMode)) {
            ForEach(viewModel.scene.analysisViews) { item in
                sidebarAnalysisRow(item)
                    .tag(Optional(WorkspaceMainRoute(tab: item.tab)))
                .disabled(!item.isEnabled)
            }
        }
    }

    var currentCorpusSection: some View {
        Section(wordZText("当前语料", "Current Corpora", mode: languageMode)) {
            sidebarCorpusRow(
                slot: viewModel.scene.targetCorpus,
                symbol: "scope"
            )

            sidebarCorpusRow(
                slot: viewModel.scene.referenceCorpus,
                symbol: "arrow.left.arrow.right.circle"
            )
        }
    }
}
