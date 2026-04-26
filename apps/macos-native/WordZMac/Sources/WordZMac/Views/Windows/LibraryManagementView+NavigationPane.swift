import SwiftUI

extension LibraryManagementView {
    var navigationPane: some View {
        NativeWindowSection(
            title: t("导航", "Navigation"),
            subtitle: t("浏览文件夹和回收站", "Browse folders and recycle items")
        ) {
            List(selection: navigationSelectionBinding) {
                Section {
                    Label(t("全部语料", "All Corpora"), systemImage: "books.vertical")
                        .tag(Optional(LibraryManagementNavigationSelection.allCorpora))

                    Label(t("回收站", "Recycle Bin"), systemImage: "trash")
                        .tag(Optional(LibraryManagementNavigationSelection.recycleBin))
                }

                foldersNavigationSection
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
