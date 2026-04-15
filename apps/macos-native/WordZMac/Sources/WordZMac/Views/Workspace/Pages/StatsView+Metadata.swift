import SwiftUI

extension StatsView {
    var metadataFiltersSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Metadata Filters", "Metadata Filters"))
                            .font(.headline)
                        Text(
                            t(
                                "当前分析会复用语料库窗口里的 metadata 筛选范围。这里保留摘要和样本预览，具体条件统一回到 Library 调整。",
                                "Analysis reuses the metadata filter scope from the Library window. This page keeps the summary and sample preview only; edit the full filters back in Library."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } actions: {
                    HStack(spacing: 8) {
                        Button(t("调整筛选", "Adjust Filters")) {
                            openWindow(id: NativeWindowRoute.library.id)
                        }

                        Button(t("清除筛选", "Clear Filters")) {
                            sidebar.clearMetadataFilters()
                        }
                        .disabled(!sidebar.hasAnyMetadataFilterInput)

                        Button(t("开始统计", "Run Stats")) { onAction(.run) }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                    }
                }

                HStack(spacing: 10) {
                    Text(sidebar.metadataFilterState.summaryText(in: languageMode) ?? t("未应用筛选条件", "No filters applied"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(t("匹配语料", "Matching Corpora") + " \(sidebar.filteredCorpusCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if sidebar.metadataFilterState.isEmpty {
                    Text(
                        t(
                            "未设置条件时，会显示当前库中的全部语料。需要缩小范围时，点击“调整筛选”到 Library 打开完整筛选面板。",
                            "When no filters are set, every corpus in the current library stays available. Use Adjust Filters to open the full editor in Library only when you need a narrower scope."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                } else if sidebar.filteredCorpora.isEmpty {
                    Label(
                        t("当前筛选没有匹配到语料，请回到 Library 调整条件。", "The current filters do not match any corpus. Return to Library and adjust the criteria."),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(t("当前匹配语料", "Matching Corpora"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(sidebar.filteredCorpora.prefix(6)), id: \.id) { corpus in
                                    metadataCorpusChip(corpus)
                                }
                                if sidebar.filteredCorpusCount > 6 {
                                    Text("+\(sidebar.filteredCorpusCount - 6)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.08), in: Capsule())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func metadataCorpusChip(_ corpus: LibraryCorpusItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(corpus.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Text("\(corpus.folderName) · \(corpus.metadata.compactSummary(in: languageMode))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
