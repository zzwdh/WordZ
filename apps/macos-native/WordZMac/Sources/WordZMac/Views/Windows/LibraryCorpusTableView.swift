import SwiftUI

struct LibraryCorpusTableView: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let corpora: [LibraryManagementCorpusSceneItem]
    @Binding var selectedCorpusIDs: Set<String>
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        List(selection: $selectedCorpusIDs) {
            ForEach(corpora) { corpus in
                corpusRow(corpus)
                    .tag(corpus.id)
                    .contextMenu { corpusContextMenu(for: corpus) }
                    .onTapGesture(count: 2) {
                        onAction(.selectCorpus(corpus.id))
                        onAction(.openSelectedCorpus)
                    }
                    .help(corpusHelpText(for: corpus))
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
        .accessibilityLabel(t("语料列表", "Corpus list"))
    }

    private func corpusRow(_ corpus: LibraryManagementCorpusSceneItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(corpus.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)

                    sourceBadge(corpus.sourceType)

                    if isDefaultReferenceCorpus(corpus) {
                        referenceBadge
                    }
                }

                HStack(spacing: 6) {
                    Image(systemName: "externaldrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(corpus.databaseFileName)
                        .font(.caption.monospaced())
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(corpus.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Text(corpus.metadataSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    metadataIssueBadges(for: corpus)

                    Text(corpus.cleaningStatusTitle)
                        .font(.caption2)
                        .foregroundStyle(cleaningTint(for: corpus.cleaningStatus))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
            }
            .layoutPriority(1)

            VStack(alignment: .leading, spacing: 6) {
                readinessBadge(for: corpus)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func readinessBadge(for corpus: LibraryManagementCorpusSceneItem) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Circle()
                .fill(readinessTint(for: corpus.readiness.level))
                .frame(width: 7, height: 7)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(corpus.readiness.title) · \(corpus.readiness.scoreText)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Text(corpus.readiness.detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(width: 150, alignment: .leading)
    }

    private func sourceBadge(_ sourceType: String) -> some View {
        Text(sourceType.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.10), in: Capsule())
            .lineLimit(1)
    }

    private var referenceBadge: some View {
        Label(t("参照", "Reference"), systemImage: "character.book.closed")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.purple)
            .lineLimit(1)
    }

    @ViewBuilder
    private func metadataIssueBadges(for corpus: LibraryManagementCorpusSceneItem) -> some View {
        if corpus.hasMissingYear {
            metadataIssueBadge(t("缺年份", "No Year"), systemImage: "calendar")
        }
        if corpus.hasMissingGenre {
            metadataIssueBadge(t("缺体裁", "No Genre"), systemImage: "text.book.closed")
        }
        if corpus.hasMissingTags {
            metadataIssueBadge(t("缺标签", "No Tags"), systemImage: "tag")
        }
        if !corpus.hasMissingYear && !corpus.hasMissingGenre && !corpus.hasMissingTags {
            Label(t("元数据完整", "Metadata Complete"), systemImage: "checkmark.circle")
                .font(.caption2)
                .foregroundStyle(.green)
        }
    }

    private func metadataIssueBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2)
            .foregroundStyle(.orange)
            .lineLimit(1)
    }

    private func isDefaultReferenceCorpus(_ corpus: LibraryManagementCorpusSceneItem) -> Bool {
        corpus.representedPath.contains("ReferenceCorpora")
            || corpus.representedPath.contains("ToRCH2014")
            || corpus.title.localizedCaseInsensitiveContains("ToRCH2014")
    }

    private func corpusHelpText(for corpus: LibraryManagementCorpusSceneItem) -> String {
        let source = corpus.representedPath.isEmpty
            ? t("WordZ DB 内部来源", "WordZ DB internal source")
            : corpus.representedPath
        return [
            corpus.title,
            corpus.databaseFileName,
            source,
            corpus.readiness.detailText
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }

    @ViewBuilder
    private func corpusContextMenu(for corpus: LibraryManagementCorpusSceneItem) -> some View {
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
        Divider()
        Button(t("重命名", "Rename")) {
            onAction(.selectCorpus(corpus.id))
            onAction(.renameSelectedCorpus)
        }
        Button(t("移到选中文件夹", "Move to Selected Folder")) {
            onAction(.selectCorpus(corpus.id))
            onAction(.moveSelectedCorpusToSelectedFolder)
        }
        Divider()
        Button(t("删除", "Delete"), role: .destructive) {
            onAction(.selectCorpus(corpus.id))
            onAction(.deleteSelectedCorpus)
        }
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }

    private func readinessTint(for level: LibraryCorpusReadinessLevel) -> Color {
        switch level {
        case .ready:
            return .green
        case .attention:
            return .orange
        case .blocked:
            return .red
        }
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
