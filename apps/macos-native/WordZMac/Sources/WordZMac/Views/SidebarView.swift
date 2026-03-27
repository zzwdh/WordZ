import SwiftUI

struct SidebarView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: LibrarySidebarViewModel
    let onAction: (SidebarAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerCard
            actionRow

            if let selected = viewModel.scene.currentCorpus {
                WorkbenchSectionCard {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(wordZText("当前语料", "Current Corpus", mode: languageMode))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(selected.title)
                            .font(.headline)
                        Text(selected.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            WorkbenchPaneCard(
                title: wordZText("本地语料库", "Local Library", mode: languageMode),
                subtitle: viewModel.scene.errorMessage.isEmpty ? "\(wordZText("共", "Saved", mode: languageMode)) \(viewModel.scene.corpora.count) \(wordZText("条已保存语料", "corpora", mode: languageMode))" : viewModel.scene.errorMessage
            ) {
                if viewModel.scene.corpora.isEmpty {
                    ContentUnavailableView(
                        wordZText("还没有可用语料", "No corpora yet", mode: languageMode),
                        systemImage: viewModel.scene.errorMessage.isEmpty ? "tray" : "exclamationmark.triangle",
                        description: Text(
                            viewModel.scene.errorMessage.isEmpty
                            ? wordZText("等引擎连接完成后，这里会显示本地语料。", "Your local corpora will appear here after the engine connects.", mode: languageMode)
                            : viewModel.scene.errorMessage
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $viewModel.selectedCorpusID) {
                        ForEach(viewModel.scene.corpora) { corpus in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(corpus.title)
                                Text(corpus.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
        .padding(16)
        .frame(minWidth: 300, idealWidth: 320, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(viewModel.scene.appName)
                        .font(.title3.weight(.semibold))
                    Text(viewModel.scene.versionLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            if !viewModel.scene.errorMessage.isEmpty {
                Text(viewModel.scene.errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            ForEach(viewModel.scene.actions) { item in
                if item.action == .openSelected {
                    Button(item.title) { onAction(item.action) }
                        .buttonStyle(.borderedProminent)
                        .disabled(!item.isEnabled)
                } else {
                    Button(item.title) { onAction(item.action) }
                        .buttonStyle(.bordered)
                        .disabled(!item.isEnabled)
                }
            }
        }
    }

    private var statusBadge: some View {
        let hasError = !viewModel.scene.errorMessage.isEmpty
        let isConnecting = viewModel.scene.engineState == .connecting && !hasError

        return HStack(spacing: 6) {
            if isConnecting {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: hasError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                    .foregroundStyle(hasError ? .red : .green)
            }
            Text(viewModel.scene.engineStatus)
                .font(.caption.weight(.medium))
                .foregroundStyle(hasError ? .red : .secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}
