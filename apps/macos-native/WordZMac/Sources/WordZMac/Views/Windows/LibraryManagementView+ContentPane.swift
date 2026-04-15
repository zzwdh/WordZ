import SwiftUI

extension LibraryManagementView {
    var libraryPrimaryContentPane: some View {
        NativeWindowSection(
            title: viewModel.scene.content.title,
            subtitle: viewModel.scene.content.subtitle
        ) {
            switch viewModel.scene.content.mode {
            case .corpora:
                corporaContent
            case .recycleBin:
                recycleContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var corporaContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.scene.corpora.isEmpty {
                ContentUnavailableView(
                    viewModel.scene.content.emptyTitle,
                    systemImage: "tray",
                    description: Text(viewModel.scene.content.emptyDescription)
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
                                HStack(spacing: 8) {
                                    Text("\(corpus.subtitle) · \(corpus.sourceType.uppercased())")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    corpusCleaningPill(for: corpus)
                                }
                                Text(corpusRowSummary(for: corpus))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
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
                            Button(t("分享语料", "Share Corpus")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.shareSelectedCorpus)
                            }
                            Button(t("语料信息", "Corpus Info")) {
                                onAction(.selectCorpus(corpus.id))
                                onAction(.showSelectedCorpusInfo)
                            }
                            if viewModel.scene.selectedCorpusIDs.count > 1,
                               viewModel.scene.selectedCorpusIDs.contains(corpus.id) {
                                Button(t("批量清洗所选语料", "Clean Selected Corpora")) {
                                    onAction(.selectCorpusIDs(viewModel.scene.selectedCorpusIDs.union([corpus.id])))
                                    onAction(.cleanSelectedCorpora)
                                }
                            } else {
                                Button(t("重新清洗", "Re-clean")) {
                                    onAction(.selectCorpus(corpus.id))
                                    onAction(.cleanSelectedCorpus)
                                }
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

            corporaSelectionActions
        }
    }

    private var corporaSelectionActions: some View {
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

                    Button(t("批量清洗所选语料", "Clean Selected Corpora")) {
                        onAction(.cleanSelectedCorpora)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(t("批量编辑元数据", "Batch Edit Metadata")) {
                        onAction(.editSelectedCorporaMetadata)
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                HStack(spacing: 10) {
                    Button(t("打开语料", "Open Corpus")) { onAction(.openSelectedCorpus) }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                    Button(t("分享语料", "Share Corpus")) { onAction(.shareSelectedCorpus) }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                    Button(t("重新清洗", "Re-clean")) { onAction(.cleanSelectedCorpus) }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.scene.selectedCorpusID == nil || viewModel.scene.selectedCorpusIDs.count != 1)
                    Spacer()
                    Text(t("空格：快速预览", "Space: Quick Look"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var recycleContent: some View {
        Group {
            if viewModel.scene.recycleEntries.isEmpty {
                ContentUnavailableView(
                    viewModel.scene.content.emptyTitle,
                    systemImage: "trash",
                    description: Text(viewModel.scene.content.emptyDescription)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    @ViewBuilder
    private func integrityMarkers(for corpus: LibraryManagementCorpusSceneItem) -> some View {
        HStack(spacing: 6) {
            if corpus.hasMissingYear {
                Image(systemName: "calendar.badge.exclamationmark")
                    .foregroundStyle(.orange)
                    .help(t("缺年份", "Missing Year"))
            }
            if corpus.hasMissingGenre {
                Image(systemName: "text.book.closed")
                    .foregroundStyle(.secondary)
                    .help(t("缺体裁", "Missing Genre"))
            }
            if corpus.hasMissingTags {
                Image(systemName: "tag.slash")
                    .foregroundStyle(.secondary)
                    .help(t("缺标签", "Missing Tags"))
            }
        }
        .font(.caption)
    }

    private func corpusRowSummary(for corpus: LibraryManagementCorpusSceneItem) -> String {
        let parts = [corpus.metadataSummary, corpus.cleaningSummary].filter { !$0.isEmpty }
        return parts.isEmpty ? corpus.cleaningStatusTitle : parts.joined(separator: " · ")
    }

    private func corpusCleaningPill(for corpus: LibraryManagementCorpusSceneItem) -> some View {
        Text(corpus.cleaningStatusTitle)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(cleaningTint(for: corpus.cleaningStatus))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(cleaningTint(for: corpus.cleaningStatus).opacity(0.12), in: Capsule())
    }

    private func cleaningTint(for status: LibraryCorpusCleaningStatus) -> Color {
        switch status {
        case .pending:
            return .orange
        case .cleaned:
            return .green
        case .cleanedWithChanges:
            return .blue
        }
    }
}
