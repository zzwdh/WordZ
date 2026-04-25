import SwiftUI

extension TopicsView {
    func topicSegmentsPane(_ scene: TopicsSceneModel) -> some View {
        WorkbenchPaneCard(
            title: t("主题片段", "Topic Segments")
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.selectedCluster?.title ?? t("全部主题片段", "All Topic Segments"))
                            .font(.headline)
                        Text(scene.pagination.rangeLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 12)
                    if let selectedRow = viewModel.selectedSceneRow {
                        Button {
                            onAction(.openSourceReader)
                        } label: {
                            Label(
                                t("打开原文视图", "Open Source View"),
                                systemImage: "doc.text.magnifyingglass"
                            )
                        }
                        .disabled(isBusy)

                        Text("\(t("段落", "Paragraph")) \(selectedRow.paragraphIndex)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                        if let sourceTitle = selectedRow.sourceTitle {
                            Text(
                                [
                                    selectedRow.groupTitle,
                                    sourceTitle
                                ]
                                .compactMap { $0 }
                                .joined(separator: " · ")
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                    WorkbenchPinnedHeaderToggle()
                }

                NativeTableView(
                    descriptor: scene.table,
                    rows: scene.tableRows,
                    selectedRowID: viewModel.selectedRowID,
                    onSelectionChange: { onAction(.selectRow($0)) },
                    onDoubleClick: { onAction(.activateRow($0)) },
                    onSortByColumn: { columnID in
                        guard let column = TopicsColumnKey(rawValue: columnID) else { return }
                        onAction(.sortByColumn(column))
                    },
                    onToggleColumnFromHeader: { columnID in
                        guard let column = TopicsColumnKey(rawValue: columnID) else { return }
                        onAction(.toggleColumn(column))
                    },
                    allowsMultipleSelection: false,
                    emptyMessage: t("当前主题没有可显示的片段。", "No topic segments are available to display."),
                    accessibilityLabel: t("Topics 片段结果表格", "Topics segments results table"),
                    activationHint: t("使用方向键浏览主题片段，按 Return 或空格可打开原文视图。", "Use arrow keys to browse topic segments, then press Return or Space to open source view.")
                )
                .frame(
                    maxWidth: .infinity,
                    minHeight: 320,
                    idealHeight: WorkbenchTablePreferences.defaultTableHeight,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .clipped()
    }
}
