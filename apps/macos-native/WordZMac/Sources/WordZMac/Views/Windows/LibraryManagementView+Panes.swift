import SwiftUI

extension LibraryManagementView {
    var folderPane: some View {
        NativeWindowSection(title: t("文件夹与语料集", "Folders & Corpus Sets")) {
            Button {
                onAction(.selectFolder(nil))
            } label: {
                Label(t("全部语料", "All Corpora"), systemImage: viewModel.scene.selectedFolderID == nil ? "checkmark.circle.fill" : "circle")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.scene.selectedFolderID == nil ? Color.accentColor : .secondary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(t("语料集", "Corpus Sets"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(viewModel.scene.corpusSetsSummary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    onAction(.selectCorpusSet(nil))
                } label: {
                    Label(
                        t("不限制语料集", "No Corpus Set"),
                        systemImage: viewModel.scene.selectedCorpusSetID == nil ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.callout.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(viewModel.scene.selectedCorpusSetID == nil ? Color.accentColor : .secondary)

                if viewModel.scene.corpusSets.isEmpty {
                    Text(t("当前还没有已保存语料集。可先筛选或多选语料，再点击“保存当前语料集”。", "No saved corpus sets yet. Filter or multi-select corpora first, then save the current set."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    List(
                        selection: Binding(
                            get: { viewModel.scene.selectedCorpusSetID },
                            set: { onAction(.selectCorpusSet($0)) }
                        )
                    ) {
                        ForEach(viewModel.scene.corpusSets) { corpusSet in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(corpusSet.title)
                                Text("\(corpusSet.subtitle) · \(corpusSet.filterSummary)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(Optional(corpusSet.id))
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
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minHeight: 150, maxHeight: 220)
                }

                HStack {
                    Button(t("保存当前语料集", "Save Current Corpus Set")) { onAction(.saveCurrentCorpusSet) }
                        .disabled(viewModel.saveableCorpusSetMembers.isEmpty)
                    Button(t("删除语料集", "Delete Corpus Set")) { onAction(.deleteSelectedCorpusSet) }
                        .disabled(viewModel.scene.selectedCorpusSetID == nil)
                    Spacer()
                }
            }

            Divider()

            List(
                selection: Binding(
                    get: { viewModel.scene.selectedFolderID },
                    set: { onAction(.selectFolder($0)) }
                )
            ) {
                ForEach(viewModel.scene.folders) { folder in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.title)
                        Text(folder.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(folder.id))
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
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button(t("重命名文件夹", "Rename Folder")) { onAction(.renameSelectedFolder) }
                    .disabled(viewModel.scene.selectedFolderID == nil)
                Button(t("删除文件夹", "Delete Folder")) { onAction(.deleteSelectedFolder) }
                    .disabled(viewModel.scene.selectedFolderID == nil)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var corpusPane: some View {
        NativeWindowSection(
            title: t("语料", "Corpora"),
            subtitle: selectedFolderSubtitle
        ) {
            if viewModel.scene.corpora.isEmpty {
                ContentUnavailableView(
                    t("当前视图没有语料", "No corpora in this view"),
                    systemImage: "tray",
                    description: Text(t("可以切换到“全部语料”，或者直接导入新语料。", "Switch back to all corpora, or import new ones directly."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(
                    selection: Binding(
                        get: { viewModel.scene.selectedCorpusIDs },
                        set: { onAction(.selectCorpusIDs($0)) }
                    )
                ) {
                    ForEach(viewModel.scene.corpora) { corpus in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(corpus.title)
                                Text("\(corpus.subtitle) · \(corpus.sourceType)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(corpus.metadataSummary)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 8)
                            integrityMarkers(for: corpus)
                        }
                        .tag(corpus.id)
                        .contextMenu {
                            Button(t("打开语料", "Open Corpus")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.openSelectedCorpus)
                            }
                            Button(t("快速预览", "Quick Look")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.quickLookSelectedCorpus)
                            }
                            Button(t("语料信息", "Corpus Info")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.showSelectedCorpusInfo)
                            }
                            Button(t("编辑元数据", "Edit Metadata")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.editSelectedCorpusMetadata)
                            }
                            Button(t("批量编辑元数据", "Batch Edit Metadata")) {
                                onAction(.selectCorpusIDs(viewModel.scene.selectedCorpusIDs.union([corpus.id])))
                                onAction(.editSelectedCorporaMetadata)
                            }
                            .disabled(!(viewModel.scene.selectedCorpusIDs.count > 1 && viewModel.scene.selectedCorpusIDs.contains(corpus.id)))
                            Button(t("重命名", "Rename")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.renameSelectedCorpus)
                            }
                            Button(t("移到选中文件夹", "Move to Selected Folder")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.moveSelectedCorpusToSelectedFolder)
                            }
                            Button(t("删除", "Delete"), role: .destructive) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.deleteSelectedCorpus)
                            }
                        }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Button(t("打开语料", "Open Corpus")) { onAction(.openSelectedCorpus) }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Button(t("快速预览", "Quick Look")) { onAction(.quickLookSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                    .keyboardShortcut(.space, modifiers: [])
                Button(t("语料信息", "Corpus Info")) { onAction(.showSelectedCorpusInfo) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Button(t("编辑元数据", "Edit Metadata")) { onAction(.editSelectedCorpusMetadata) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Button(t("批量编辑元数据", "Batch Edit Metadata")) { onAction(.editSelectedCorporaMetadata) }
                    .disabled(viewModel.scene.selectedCorpusIDs.count < 2)
                Button(t("重命名语料", "Rename Corpus")) { onAction(.renameSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Button(t("移到选中文件夹", "Move to Selected Folder")) { onAction(.moveSelectedCorpusToSelectedFolder) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedFolderID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Button(t("删除语料", "Delete Corpus")) { onAction(.deleteSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                Spacer()
                Text(t("空格：快速预览", "Space: Quick Look"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var recyclePane: some View {
        NativeWindowSection(title: t("回收站", "Recycle Bin"), subtitle: viewModel.scene.recycleSummary) {
            List(
                selection: Binding(
                    get: { viewModel.scene.selectedRecycleEntryID },
                    set: { onAction(.selectRecycleEntry($0)) }
                )
            ) {
                ForEach(viewModel.scene.recycleEntries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.title)
                        Text("\(entry.typeLabel) · \(entry.subtitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(Optional(entry.id))
                    .contextMenu {
                        Button(t("恢复项目", "Restore Item")) {
                            onAction(.selectRecycleEntry(entry.id))
                            onAction(.restoreSelectedRecycleEntry)
                        }
                        Button(t("彻底删除", "Delete Permanently"), role: .destructive) {
                            onAction(.selectRecycleEntry(entry.id))
                            onAction(.purgeSelectedRecycleEntry)
                        }
                    }
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Button(t("恢复", "Restore")) { onAction(.restoreSelectedRecycleEntry) }
                    .disabled(viewModel.scene.selectedRecycleEntryID == nil)
                Button(t("彻底删除", "Delete Permanently")) { onAction(.purgeSelectedRecycleEntry) }
                    .disabled(viewModel.scene.selectedRecycleEntryID == nil)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var selectedFolderSubtitle: String {
        if let selectedFolderID = viewModel.scene.selectedFolderID,
           let selectedFolder = viewModel.scene.folders.first(where: { $0.id == selectedFolderID }) {
            return "\(selectedFolder.title) · \(viewModel.scene.corpora.count) \(t("条语料", "corpora"))"
        }
        return "\(t("全部语料", "All Corpora")) · \(viewModel.scene.corpora.count) \(t("条", "items"))"
    }

    @ViewBuilder
    private func integrityMarkers(for corpus: LibraryManagementCorpusSceneItem) -> some View {
        HStack(spacing: 6) {
            if corpus.hasMissingYear {
                Label(t("缺年份", "Missing Year"), systemImage: "calendar.badge.exclamationmark")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            if corpus.hasMissingGenre {
                Label(t("缺体裁", "Missing Genre"), systemImage: "text.book.closed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if corpus.hasMissingTags {
                Label(t("缺标签", "Missing Tags"), systemImage: "tag.slash")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
