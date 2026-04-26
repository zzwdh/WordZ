import SwiftUI

extension StatsView {
    var metadataFiltersSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchInlineActionStrip {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("统计范围", "Stats Scope"))
                            .font(.headline)
                        Text(
                            t(
                                "统计默认面向当前语料库。若已经设置高级范围，这里只显示摘要和样本预览。",
                                "Stats runs on the current library by default. If an advanced scope is active, this area only shows the summary and sample preview."
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                } actions: {
                    HStack(spacing: 8) {
                        if sidebar.hasAnyMetadataFilterInput {
                            Button(t("清除范围", "Clear Scope")) {
                                sidebar.clearMetadataFilters()
                            }
                        }

                        Button(t("开始统计", "Run Stats")) { onAction(.run) }
                            .buttonStyle(.borderedProminent)
                            .disabled(isBusy)
                    }
                }

                HStack(spacing: 10) {
                    Text(sidebar.metadataFilterState.summaryText(in: languageMode) ?? t("全部语料", "All corpora"))
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
                            "当前使用完整语料库，更适合展示和快速概览。",
                            "The full library is active, which is better for presentation and quick overview."
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
