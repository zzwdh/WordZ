import SwiftUI

extension StatsView {
    var metadataFiltersSection: some View {
        WorkbenchToolbarSection {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(t("Metadata Filters", "Metadata Filters"))
                            .font(.headline)
                        Text(t("按来源、年份、体裁或标签缩小可选语料范围。侧边栏会同步显示摘要，Target / Reference 选择也会跟着更新。", "Use source, year, genre, or tags to narrow the available corpora. The sidebar summary and Target / Reference choices update at the same time."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button(t("清除筛选", "Clear Filters")) {
                        sidebar.clearMetadataFilters()
                    }
                    .disabled(sidebar.metadataFilterState.isEmpty)
                }

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                    GridRow {
                        metadataField(title: t("来源", "Source"), text: $sidebar.metadataSourceQuery, prompt: t("如：教材 / 期刊", "e.g. textbook / journal"))
                        metadataField(title: t("年份", "Year"), text: $sidebar.metadataYearQuery, prompt: t("如：2024", "e.g. 2024"))
                    }
                    GridRow {
                        metadataField(title: t("体裁", "Genre"), text: $sidebar.metadataGenreQuery, prompt: t("如：学术 / 教学", "e.g. academic / teaching"))
                        metadataField(title: t("标签", "Tags"), text: $sidebar.metadataTagsQuery, prompt: t("多个标签用逗号分隔", "Separate tags with commas"))
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
                    Text(t("未设置条件时，会显示当前库中的全部语料。需要缩小范围时，再按来源、年份、体裁或标签输入关键词即可。", "When no filters are set, every corpus in the current library stays available. Add source, year, genre, or tag terms only when you want to narrow the analysis set."))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if sidebar.filteredCorpora.isEmpty {
                    Label(
                        t("当前筛选没有匹配到语料，请调整条件。", "The current filters do not match any corpus. Adjust the filter terms to continue."),
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
            Text(corpus.metadata.compactSummary(in: languageMode))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func metadataField(
        title: String,
        text: Binding<String>,
        prompt: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(prompt, text: text)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
