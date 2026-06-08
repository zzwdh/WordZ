import SwiftUI

extension LibraryManagementView {
    var libraryNavigationSidebar: some View {
        List(selection: navigationSelectionBinding) {
            Section {
                Label("Corpus Library", systemImage: "books.vertical")
                    .tag(Optional(LibraryManagementNavigationSelection.allCorpora))

                Label(t("导入语料", "Import Corpus"), systemImage: "tray.and.arrow.down")
                    .tag(Optional(LibraryManagementNavigationSelection.corpusBuilder))
            }

            Section {
                Label(t("回收站", "Recycle Bin"), systemImage: "trash")
                    .tag(Optional(LibraryManagementNavigationSelection.recycleBin))
            }

            foldersNavigationSection
            if !viewModel.scene.recentCorpusSets.isEmpty {
                recentCorpusSetsNavigationSection
            }
            if !viewModel.scene.corpusSets.isEmpty {
                corpusSetsNavigationSection
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(t("语料库", "Library"))
    }

    private var foldersNavigationSection: some View {
        Section {
            ForEach(viewModel.scene.folders) { folder in
                navigationRow(
                    title: folder.title,
                    detail: folder.subtitle,
                    systemImage: "folder"
                )
                .tag(Optional(LibraryManagementNavigationSelection.folder(folder.id)))
                .contextMenu {
                    Button(t("重命名文件夹", "Rename Folder")) {
                        onAction(.selectFolder(folder.id))
                        onAction(.renameSelectedFolder)
                    }
                    Button(t("删除文件夹", "Delete Folder"), role: .destructive) {
                        onAction(.selectFolder(folder.id))
                        onAction(.deleteSelectedFolder)
                    }
                }
            }
        } header: {
            navigationSectionHeader(title: t("文件夹", "Folders"), summary: nil) {
                Button(t("新建文件夹", "New Folder")) { onAction(.createFolder) }
                if viewModel.scene.selectedFolderID != nil {
                    Divider()
                    Button(t("重命名文件夹", "Rename Folder")) { onAction(.renameSelectedFolder) }
                    Button(t("删除文件夹", "Delete Folder"), role: .destructive) { onAction(.deleteSelectedFolder) }
                }
            }
        }
    }

    private var recentCorpusSetsNavigationSection: some View {
        Section {
            ForEach(viewModel.scene.recentCorpusSets) { corpusSet in
                corpusSetNavigationRow(corpusSet)
                    .tag(Optional(LibraryManagementNavigationSelection.recentCorpusSet(corpusSet.id)))
            }
        } header: {
            navigationSectionHeader(
                title: t("最近语料集", "Recent Sets"),
                summary: viewModel.scene.recentCorpusSetsSummary
            )
        }
    }

    private var corpusSetsNavigationSection: some View {
        Section {
            ForEach(viewModel.scene.corpusSets) { corpusSet in
                corpusSetNavigationRow(corpusSet)
                    .tag(Optional(LibraryManagementNavigationSelection.savedCorpusSet(corpusSet.id)))
            }
        } header: {
            navigationSectionHeader(title: t("语料集", "Corpus Sets"), summary: viewModel.scene.corpusSetsSummary) {
                Button(t("保存为语料集", "Save as Corpus Set")) { onAction(.saveCurrentCorpusSet) }
                if viewModel.scene.selectedCorpusSetID != nil {
                    Divider()
                    Button(t("删除语料集", "Delete Corpus Set"), role: .destructive) {
                        onAction(.deleteSelectedCorpusSet)
                    }
                }
            }
        }
    }

    private func corpusSetNavigationRow(_ corpusSet: LibraryManagementCorpusSetSceneItem) -> some View {
        navigationRow(
            title: corpusSet.title,
            detail: "\(corpusSet.kindTitle) · \(corpusSet.subtitle)",
            systemImage: corpusSet.isSmart ? "line.3.horizontal.decrease.circle" : "tray.full"
        )
        .contextMenu {
            Button(t("打开语料集", "Open Corpus Set")) {
                onAction(.selectCorpusSet(corpusSet.id))
            }
            Button(t("保存为语料集", "Save as Corpus Set")) {
                onAction(.saveCurrentCorpusSet)
            }
            Button(t("删除语料集", "Delete Corpus Set"), role: .destructive) {
                onAction(.selectCorpusSet(corpusSet.id))
                onAction(.deleteSelectedCorpusSet)
            }
        }
    }

    private func navigationRow(title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var navigationSelectionBinding: Binding<LibraryManagementNavigationSelection?> {
        Binding(
            get: { viewModel.scene.navigationSelection },
            set: { nextSelection in
                guard let nextSelection else { return }
                switch nextSelection {
                case .allCorpora:
                    onAction(.selectFolder(nil))
                case .corpusBuilder:
                    onAction(.showCorpusBuilder)
                case .folder(let folderID):
                    onAction(.selectFolder(folderID))
                case .savedCorpusSet(let corpusSetID), .recentCorpusSet(let corpusSetID):
                    onAction(.selectCorpusSet(corpusSetID))
                case .recycleBin:
                    onAction(.selectRecycleEntry(viewModel.scene.selectedRecycleEntryID))
                }
            }
        )
    }

    private func navigationSectionHeader<Actions: View>(
        title: String,
        summary: String?,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Menu(content: actions) {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
    }

    private func navigationSectionHeader(title: String, summary: String?) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if let summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
        }
    }
}
