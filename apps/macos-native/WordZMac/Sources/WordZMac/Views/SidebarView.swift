import SwiftUI

struct SidebarView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: LibrarySidebarViewModel
    let onAction: (SidebarAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkbenchPaneCard(
                title: wordZText("本地语料库", "Local Library", mode: languageMode),
                subtitle: viewModel.scene.errorMessage.isEmpty ? nil : viewModel.scene.errorMessage
            ) {
                if viewModel.scene.corpora.isEmpty {
                    ContentUnavailableView(
                        wordZText("还没有可用语料", "No corpora yet", mode: languageMode),
                        systemImage: viewModel.scene.errorMessage.isEmpty ? "tray" : "exclamationmark.triangle",
                        description: Text(
                            viewModel.scene.errorMessage.isEmpty
                            ? wordZText("导入语料或刷新后，这里会显示本地语料。", "Import corpora or refresh to see your local library here.", mode: languageMode)
                            : viewModel.scene.errorMessage
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $viewModel.selectedCorpusID) {
                        ForEach(viewModel.scene.corpora) { corpus in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(corpus.title)
                                        .lineLimit(1)
                                    Text(corpus.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Spacer(minLength: 0)
                                Button {
                                    onAction(.quickLookSelected(corpus.id))
                                } label: {
                                    Image(systemName: "eye.circle.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.blue)
                                }
                                .buttonStyle(.borderless)
                                .help(wordZText("快速预览这条语料", "Quick Look this corpus", mode: languageMode))
                            }
                            .tag(Optional(corpus.id))
                        }
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 16)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 360, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
