import SwiftUI

struct LibraryManagementView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var viewModel: LibraryManagementViewModel
    let onAction: (LibraryManagementAction) -> Void

    private var folderItems: [LibraryManagementFolderSceneItem] { viewModel.scene.folders }
    private var corpusItems: [LibraryManagementCorpusSceneItem] { viewModel.scene.corpora }
    private var recycleItems: [LibraryManagementRecycleSceneItem] { viewModel.scene.recycleEntries }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: t("语料库", "Library"), subtitle: viewModel.scene.librarySummary) {
                Toggle(t("保留目录结构", "Preserve Folder Structure"), isOn: $viewModel.preserveHierarchy)
                    .toggleStyle(.switch)
                    .frame(maxWidth: 180)
            }

            WorkbenchToolbarSection {
                HStack(spacing: 10) {
                    Button(t("刷新", "Refresh")) { onAction(.refresh) }
                    Button(t("导入语料", "Import Corpora")) { onAction(.importPaths) }
                    Button(t("新建文件夹", "New Folder")) { onAction(.createFolder) }
                    Button(t("备份", "Backup")) { onAction(.backupLibrary) }
                    Button(t("恢复", "Restore")) { onAction(.restoreLibrary) }
                    Button(t("修复", "Repair")) { onAction(.repairLibrary) }
                    Spacer()
                    Text(viewModel.scene.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HSplitView {
                folderPane
                    .frame(minWidth: 220, idealWidth: 240)

                corpusPane
                    .frame(minWidth: 360, idealWidth: 420)

                VSplitView {
                    recyclePane
                        .frame(minHeight: 220)

                    WorkbenchPaneCard(
                        title: "详情",
                        subtitle: viewModel.scene.inspector.subtitle
                    ) {
                        LibraryInspectorView(
                            scene: viewModel.scene.inspector,
                            onAction: onAction
                        )
                    }
                    .frame(minHeight: 220)
                }
                .frame(minWidth: 280, idealWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(item: $viewModel.corpusInfoSheet) { scene in
            LibraryCorpusInfoSheetView(scene: scene)
        }
    }

    private var folderPane: some View {
        WorkbenchPaneCard(title: t("文件夹", "Folders")) {
            Button {
                onAction(.selectFolder(nil))
            } label: {
                Label(t("全部语料", "All Corpora"), systemImage: viewModel.scene.selectedFolderID == nil ? "checkmark.circle.fill" : "circle")
                    .font(.callout.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(viewModel.scene.selectedFolderID == nil ? Color.accentColor : .secondary)

            List(
                selection: Binding(
                    get: { viewModel.scene.selectedFolderID },
                    set: { onAction(.selectFolder($0)) }
                )
            ) {
                ForEach(folderItems) { folder in
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
    }

    private var corpusPane: some View {
        WorkbenchPaneCard(
            title: t("语料", "Corpora"),
            subtitle: selectedFolderSubtitle
        ) {
            if corpusItems.isEmpty {
                ContentUnavailableView(
                    t("当前视图没有语料", "No corpora in this view"),
                    systemImage: "tray",
                    description: Text(t("可以切换到“全部语料”，或者直接导入新语料。", "Switch back to all corpora, or import new ones directly."))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(
                    selection: Binding(
                        get: { viewModel.scene.selectedCorpusID },
                        set: { onAction(.selectCorpus($0)) }
                    )
                ) {
                    ForEach(corpusItems) { corpus in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(corpus.title)
                            Text("\(corpus.subtitle) · \(corpus.sourceType)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(Optional(corpus.id))
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
                    .disabled(viewModel.scene.selectedCorpusID == nil)
                Button(t("快速预览", "Quick Look")) { onAction(.quickLookSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil)
                    .keyboardShortcut(.space, modifiers: [])
                Button(t("语料信息", "Corpus Info")) { onAction(.showSelectedCorpusInfo) }
                    .disabled(viewModel.scene.selectedCorpusID == nil)
                Button(t("重命名语料", "Rename Corpus")) { onAction(.renameSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil)
                Button(t("移到选中文件夹", "Move to Selected Folder")) { onAction(.moveSelectedCorpusToSelectedFolder) }
                    .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedFolderID == nil)
                Button(t("删除语料", "Delete Corpus")) { onAction(.deleteSelectedCorpus) }
                    .disabled(viewModel.scene.selectedCorpusID == nil)
                Spacer()
                Text(t("空格：快速预览", "Space: Quick Look"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recyclePane: some View {
        WorkbenchPaneCard(title: t("回收站", "Recycle Bin"), subtitle: viewModel.scene.recycleSummary) {
            List(
                selection: Binding(
                    get: { viewModel.scene.selectedRecycleEntryID },
                    set: { onAction(.selectRecycleEntry($0)) }
                )
            ) {
                ForEach(recycleItems) { entry in
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
    }

    private var selectedFolderSubtitle: String {
        if let selectedFolderID = viewModel.scene.selectedFolderID,
           let selectedFolder = folderItems.first(where: { $0.id == selectedFolderID }) {
            return "\(selectedFolder.title) · \(viewModel.scene.corpora.count) \(t("条语料", "corpora"))"
        }
        return "\(t("全部语料", "All Corpora")) · \(viewModel.scene.corpora.count) \(t("条", "items"))"
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct LibraryCorpusInfoSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.wordZLanguageMode) private var languageMode
    let scene: LibraryCorpusInfoSceneModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkbenchHeaderCard(title: scene.title, subtitle: scene.subtitle) {
                Button(t("关闭", "Close")) {
                    dismiss()
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                WorkbenchMetricCard(title: "Tokens", value: scene.tokenCountText)
                WorkbenchMetricCard(title: "Types", value: scene.typeCountText)
                WorkbenchMetricCard(title: "TTR", value: scene.ttrText)
                WorkbenchMetricCard(title: "STTR", value: scene.sttrText)
            }

            WorkbenchPaneCard(
                title: t("语料详情", "Corpus Details"),
                subtitle: t("当前语料的基础统计与来源信息", "Core statistics and source information for the selected corpus")
            ) {
                detailRow(title: t("文件夹", "Folder"), value: scene.folderName)
                detailRow(title: t("来源类型", "Source Type"), value: scene.sourceType.uppercased())
                detailRow(title: t("原始路径", "Original Path"), value: scene.representedPath.isEmpty ? "—" : scene.representedPath)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360, alignment: .topLeading)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}

private struct LibraryInspectorView: View {
    let scene: LibraryManagementInspectorSceneModel
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(scene.title)
                    .font(.headline)
                Text(scene.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !scene.details.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.details) { detail in
                        HStack(alignment: .firstTextBaseline) {
                            Text(detail.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 84, alignment: .leading)
                            Text(detail.value)
                                .font(.callout)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            if !scene.actions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scene.actions) { item in
                        if item.role == .primary {
                            Button(item.title) { onAction(item.action) }
                                .buttonStyle(.borderedProminent)
                        } else {
                            Button(item.title) { onAction(item.action) }
                                .buttonStyle(.bordered)
                                .tint(item.role == .destructive ? .red : .accentColor)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
