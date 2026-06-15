import SwiftUI
import WordZShared

extension LibraryManagementView {
    var libraryPrimaryContentPane: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch viewModel.scene.content.mode {
            case .corpora:
                corporaContent
            case .corpusBuilder:
                corpusBuilderContent
            case .recycleBin:
                recycleContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var corporaContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scene.corpora.isEmpty {
                libraryEmptyState(
                    title: viewModel.scene.content.emptyTitle,
                    description: viewModel.scene.content.emptyDescription,
                    systemImage: "tray",
                    showsImportAction: true
                )
            } else {
                LibraryCorpusTableView(
                    corpora: viewModel.scene.corpora,
                    selectedCorpusIDs: Binding(
                        get: { viewModel.scene.selectedCorpusIDs },
                        set: { onAction(.selectCorpusIDs($0)) }
                    ),
                    onAction: onAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    if hasCorpusSelection {
                        corporaSelectionActions
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
        }
    }

    private var corpusBuilderContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            AdaptiveToolbarSurface {
                HStack(spacing: 12) {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Import Corpus")
                            .font(.callout.weight(.semibold))
                        Text(t("选择文件生成可分析语料", "Choose files and create an analyzable corpus"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    Button {
                        onAction(.importPaths)
                    } label: {
                        Label(t("选择文件", "Choose Files"), systemImage: "plus")
                    }
                    .adaptiveGlassButtonStyle(prominent: true)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            LibraryCorpusBuilderReferenceView(
                corpusCount: viewModel.scene.corpora.count,
                folderCount: viewModel.scene.folders.count,
                onBuild: { onAction(.importPaths) }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            englishReferenceCorpusPanel
        }
    }

    private var englishReferenceCorpusPanel: some View {
        AdaptiveToolbarSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(t("英文参照语料", "English Reference Corpora"))
                            .font(.callout.weight(.semibold))
                        Text(t("按需下载并添加到关键词分析的参照语料集", "Download on demand and add them as keyword reference sets"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    ForEach(EnglishReferenceCorpusCatalog.all) { item in
                        Button {
                            onAction(.installEnglishReferenceCorpus(item.kind))
                        } label: {
                            Label(item.shortName, systemImage: item.kind == .bnc1994 ? "text.book.closed" : "book")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.small)
                        .adaptiveGlassButtonStyle()
                        .help(item.summary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var hasCorpusSelection: Bool {
        !viewModel.scene.selectedCorpusIDs.isEmpty || viewModel.scene.selectedCorpusID != nil
    }

    private var corporaSelectionActions: some View {
        AdaptiveSelectionAccessorySurface {
            Group {
                if viewModel.scene.selectedCorpusIDs.count > 1 {
                    HStack(spacing: 10) {
                        Label(
                            t("已选择 \(viewModel.scene.selectedCorpusIDs.count) 条语料", "Selected \(viewModel.scene.selectedCorpusIDs.count) corpora"),
                            systemImage: "square.stack.3d.down.right"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer(minLength: 0)

                        selectionActionButton(
                            title: t("保存为语料集", "Save as Set"),
                            systemImage: "tray.full",
                            isProminent: true
                        ) {
                            onAction(.saveCurrentCorpusSet)
                        }
                    }
                } else {
                    let hasSingleSelection = viewModel.scene.selectedCorpusID != nil
                        && viewModel.scene.selectedCorpusIDs.count == 1

                    HStack(spacing: 10) {
                        selectionActionButton(
                            title: t("打开", "Open"),
                            systemImage: "doc.text.magnifyingglass",
                            isEnabled: hasSingleSelection,
                            isProminent: true
                        ) {
                            onAction(.openSelectedCorpus)
                        }

                        selectionActionButton(
                            title: t("详情", "Details"),
                            systemImage: "info.circle",
                            isEnabled: hasSingleSelection
                        ) {
                            onAction(.showSelectedCorpusInfo)
                        }

                        selectionActionButton(
                            title: t("重命名", "Rename"),
                            systemImage: "pencil",
                            isEnabled: hasSingleSelection
                        ) {
                            onAction(.renameSelectedCorpus)
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private func selectionActionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .controlSize(.small)
        .adaptiveGlassButtonStyle(prominent: isProminent)
        .disabled(!isEnabled)
    }

    private var recycleSelectionActions: some View {
        AdaptiveSelectionAccessorySurface {
            HStack(spacing: 10) {
                Label(
                    viewModel.scene.selectedRecycleEntryID == nil
                        ? t("未选择回收站项目", "No recycle item selected")
                        : t("已选择回收站项目", "Recycle item selected"),
                    systemImage: "trash"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                selectionActionButton(
                    title: t("恢复", "Restore"),
                    systemImage: "arrow.uturn.backward",
                    isEnabled: viewModel.scene.selectedRecycleEntryID != nil,
                    isProminent: true
                ) {
                    onAction(.restoreSelectedRecycleEntry)
                }

                selectionActionButton(
                    title: t("彻底删除", "Delete Permanently"),
                    systemImage: "trash.slash",
                    isEnabled: viewModel.scene.selectedRecycleEntryID != nil
                ) {
                    onAction(.purgeSelectedRecycleEntry)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var recycleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scene.recycleEntries.isEmpty {
                libraryEmptyState(
                    title: viewModel.scene.content.emptyTitle,
                    description: viewModel.scene.content.emptyDescription,
                    systemImage: "trash",
                    showsImportAction: false
                )
            } else {
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
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    if viewModel.scene.selectedRecycleEntryID != nil {
                        recycleSelectionActions
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.easeInOut(duration: 0.16), value: viewModel.scene.selectedRecycleEntryID)
            }
        }
    }

    private func libraryEmptyState(
        title: String,
        description: String,
        systemImage: String,
        showsImportAction: Bool
    ) -> some View {
        AdaptiveEmptyStateSurface {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if showsImportAction {
                    Button {
                        onAction(.importPaths)
                    } label: {
                        Label(t("添加文件", "Add Files"), systemImage: "plus")
                    }
                    .adaptiveGlassButtonStyle(prominent: true)
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}

private struct LibraryCorpusBuilderReferenceView: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let corpusCount: Int
    let folderCount: Int
    let onBuild: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 12)], spacing: 12) {
                NativeMetricTile(title: t("语料", "Corpora"), value: "\(corpusCount)")
                NativeMetricTile(title: t("文件夹", "Folders"), value: "\(folderCount)")
                NativeMetricTile(title: t("支持格式", "Supported"), value: "TXT · DOCX · PDF")
                NativeMetricTile(title: t("默认名称", "Default Name"), value: "我的语料库")
            }

            VStack(alignment: .leading, spacing: 0) {
                builderDetailRow(title: t("输入", "Input"), value: t("TXT、DOCX、PDF 文件", "TXT, DOCX, PDF files"))
                Divider()
                builderDetailRow(title: t("导入", "Import"), value: t("合并为一条可分析语料", "Merged into one analyzable corpus"))
                Divider()
                builderDetailRow(title: t("管理", "Manage"), value: t("可重命名、移动、补齐元数据", "Rename, move, and complete metadata"))
                Divider()
                builderDetailRow(title: t("复用", "Reuse"), value: t("可保存为命名语料集", "Save as a named corpus set"))
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button(action: onBuild) {
                Label(t("选择文件", "Choose Files"), systemImage: "plus")
            }
            .adaptiveGlassButtonStyle(prominent: true)

            Spacer(minLength: 0)
        }
    }

    private func builderDetailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
