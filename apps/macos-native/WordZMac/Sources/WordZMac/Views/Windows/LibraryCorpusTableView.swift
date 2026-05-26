import SwiftUI

struct LibraryCorpusTableView: View {
    @Environment(\.wordZLanguageMode) private var languageMode

    let corpora: [LibraryManagementCorpusSceneItem]
    @Binding var selectedCorpusIDs: Set<String>
    let onAction: (LibraryManagementAction) -> Void

    var body: some View {
        Table(corpora, selection: $selectedCorpusIDs) {
            TableColumn(t("DB 语料库", "DB Corpus")) { corpus in
                corpusNameCell(corpus)
                    .contextMenu { corpusContextMenu(for: corpus) }
                    .onTapGesture(count: 2) {
                        onAction(.selectCorpus(corpus.id))
                        onAction(.openSelectedCorpus)
                    }
            }
            .width(min: 180, ideal: 240)

            TableColumn(t("DB 文件", "DB File")) { corpus in
                Text(corpus.databaseFileName)
                    .font(.callout.monospaced())
                    .lineLimit(1)
                    .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 160, ideal: 220)

            TableColumn(t("可用度", "Readiness")) { corpus in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(readinessTint(for: corpus.readiness.level))
                            .frame(width: 7, height: 7)
                        Text("\(corpus.readiness.title) · \(corpus.readiness.scoreText)")
                            .font(.callout.weight(.medium))
                            .lineLimit(1)
                    }
                    Text(corpus.readiness.detailText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 160, ideal: 220)

            TableColumn(t("文件夹", "Folder")) { corpus in
                Text(corpus.subtitle)
                    .lineLimit(1)
                    .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 96, ideal: 130, max: 220)

            TableColumn(t("源格式", "Source Format")) { corpus in
                Text(corpus.sourceType.uppercased())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 88, ideal: 110, max: 140)

            TableColumn(t("项目状态", "Project Status")) { corpus in
                VStack(alignment: .leading, spacing: 2) {
                    Text(corpus.metadataSummary)
                        .lineLimit(1)
                    Text(corpus.cleaningStatusTitle)
                        .font(.caption)
                        .foregroundStyle(corpus.cleaningStatus == .pending ? .orange : .secondary)
                        .lineLimit(1)
                }
                .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 160, ideal: 220)

            TableColumn(t("来源链", "Source Chain")) { corpus in
                VStack(alignment: .leading, spacing: 2) {
                    Text(corpus.representedPath.isEmpty ? t("WordZ DB 内部来源", "WordZ DB internal source") : corpus.representedPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(t("中文/中英混合可分析", "Chinese/mixed analysis ready"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .contextMenu { corpusContextMenu(for: corpus) }
            }
            .width(min: 220, ideal: 320)
        }
        .tableStyle(.inset(alternatesRowBackgrounds: false))
        .scrollContentBackground(.hidden)
        .accessibilityLabel(t("语料表格", "Corpus table"))
    }

    private func corpusNameCell(_ corpus: LibraryManagementCorpusSceneItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(corpus.title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Text("DB")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
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
}
