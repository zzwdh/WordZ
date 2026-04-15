import SwiftUI

extension LibraryManagementView {
    var navigationPane: some View {
        NativeWindowSection(
            title: t("导航", "Navigation"),
            subtitle: t("浏览文件夹、语料集和回收站", "Browse folders, corpus sets, and recycle items")
        ) {
            List(selection: navigationSelectionBinding) {
                Section {
                    Label(t("全部语料", "All Corpora"), systemImage: "books.vertical")
                        .tag(Optional(LibraryManagementNavigationSelection.allCorpora))

                    Label(t("回收站", "Recycle Bin"), systemImage: "trash")
                        .tag(Optional(LibraryManagementNavigationSelection.recycleBin))
                }

                foldersNavigationSection
                recentCorpusSetsNavigationSection
                savedCorpusSetsNavigationSection
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var foldersNavigationSection: some View {
        Section {
            ForEach(viewModel.scene.folders) { folder in
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.title)
                    Text(folder.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            if viewModel.scene.recentCorpusSets.isEmpty {
                Text(
                    t(
                        "开始应用或保存语料集后，这里会显示最近使用记录。",
                        "Applied or newly saved corpus sets will appear here for quick reuse."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(viewModel.scene.recentCorpusSets) { corpusSet in
                    corpusSetNavigationRow(corpusSet)
                        .tag(Optional(LibraryManagementNavigationSelection.recentCorpusSet(corpusSet.id)))
                }
            }
        } header: {
            navigationSectionHeader(
                title: t("最近使用", "Recent"),
                summary: viewModel.scene.recentCorpusSetsSummary
            )
        }
    }

    private var savedCorpusSetsNavigationSection: some View {
        Section {
            if viewModel.scene.corpusSets.isEmpty {
                Text(
                    t(
                        "当前还没有已保存语料集。可先筛选或多选语料，再点击“保存当前语料集”。",
                        "No saved corpus sets yet. Filter or multi-select corpora first, then save the current set."
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(viewModel.scene.corpusSets) { corpusSet in
                    corpusSetNavigationRow(corpusSet)
                        .tag(Optional(LibraryManagementNavigationSelection.savedCorpusSet(corpusSet.id)))
                }
            }
        } header: {
            navigationSectionHeader(
                title: t("已保存语料集", "Saved Corpus Sets"),
                summary: viewModel.scene.corpusSetsSummary
            ) {
                Button(t("保存当前语料集", "Save Current Corpus Set")) { onAction(.saveCurrentCorpusSet) }
                    .disabled(viewModel.saveableCorpusSetMembers.isEmpty)
                if viewModel.scene.selectedCorpusSetID != nil {
                    Divider()
                    Button(t("更新为当前语料集", "Update with Current Scope")) { onAction(.saveCurrentCorpusSet) }
                    Button(t("删除语料集", "Delete Corpus Set"), role: .destructive) { onAction(.deleteSelectedCorpusSet) }
                }
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

    private func corpusSetNavigationRow(_ corpusSet: LibraryManagementCorpusSetSceneItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(corpusSet.title)
            Text("\(corpusSet.subtitle) · \(corpusSet.filterSummary)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .contextMenu {
            Button(t("应用语料集", "Apply Corpus Set")) {
                onAction(.selectCorpusSet(corpusSet.id))
            }
            Button(t("更新为当前语料集", "Update with Current Scope")) {
                onAction(.selectCorpusSet(corpusSet.id))
                onAction(.saveCurrentCorpusSet)
            }
            Button(t("删除语料集", "Delete Corpus Set"), role: .destructive) {
                onAction(.selectCorpusSet(corpusSet.id))
                onAction(.deleteSelectedCorpusSet)
            }
        }
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
