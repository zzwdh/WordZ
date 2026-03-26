import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: MainWorkspaceViewModel
    let onRefresh: () -> Void
    let onOpenSelected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.appInfo?.name ?? "WordZ")
                    .font(.title3.weight(.semibold))
                Text(viewModel.appInfo?.version.isEmpty == false ? "v\(viewModel.appInfo?.version ?? "")" : "mac native preview")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.engineStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("刷新") { onRefresh() }
                Button("打开选中") { onOpenSelected() }
                    .disabled(viewModel.selectedCorpusID == nil)
            }

            if let selected = viewModel.selectedCorpus {
                VStack(alignment: .leading, spacing: 4) {
                    Text("当前语料")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selected.name)
                        .font(.headline)
                    Text(selected.folderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text("本地语料库")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            List(selection: $viewModel.selectedCorpusID) {
                ForEach(viewModel.librarySnapshot.corpora) { corpus in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(corpus.name)
                        Text(corpus.folderName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(corpus.id))
                }
            }
            .listStyle(.inset)

            Spacer(minLength: 0)

            if !viewModel.lastErrorMessage.isEmpty {
                Text(viewModel.lastErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(16)
        .frame(minWidth: 280)
    }
}
