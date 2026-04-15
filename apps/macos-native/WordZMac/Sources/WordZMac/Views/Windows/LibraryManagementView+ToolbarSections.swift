import SwiftUI

extension LibraryManagementView {
    var libraryUtilityBar: some View {
        NativeWindowSection(
            title: t("当前范围", "Current Scope"),
            subtitle: viewModel.scene.statusMessage
        ) {
            AdaptiveToolbarSurface {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.scene.currentScopeSummary)
                            .font(.callout.weight(.semibold))
                        Text(viewModel.scene.content.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 16)
                    filterButton
                }
            }

            HStack(alignment: .center, spacing: 10) {
                Text(t("自动清洗", "Auto-Cleaning"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                cleaningSummaryChip(
                    title: t("已清洗", "Cleaned"),
                    count: viewModel.scene.autoCleaningSummary.cleanedCount,
                    tint: .green
                )
                cleaningSummaryChip(
                    title: t("待清洗", "Pending"),
                    count: viewModel.scene.autoCleaningSummary.pendingCount,
                    tint: .orange
                )
                cleaningSummaryChip(
                    title: t("本轮有变更", "Changed"),
                    count: viewModel.scene.autoCleaningSummary.changedCount,
                    tint: .blue
                )

                Spacer(minLength: 0)
            }

            HStack(alignment: .center, spacing: 10) {
                if !viewModel.scene.filterChips.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.scene.filterChips) { chip in
                                filterChip(chip)
                            }
                        }
                    }
                } else {
                    Text(t("未应用筛选或完整性提示。需要缩小范围时，再展开筛选面板即可。", "No active filters or integrity prompts. Open the filter panel only when you need to narrow the scope."))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                utilityStatusView
            }
        }
    }

    private var filterButton: some View {
        Button {
            isShowingMetadataFilters = true
        } label: {
            Label(
                t("筛选", "Filters"),
                systemImage: viewModel.scene.metadataFilterSummary == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
        .popover(isPresented: $isShowingMetadataFilters, arrowEdge: .top) {
            metadataFilterEditorPopover
        }
    }

    private var metadataFilterEditorPopover: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("元数据筛选", "Metadata Filters"))
                        .font(.headline)
                    Text(
                        t(
                            "按来源、年份范围、体裁和标签缩小当前语料范围。筛选结果会同步到主工作区和命名语料集。",
                            "Narrow the current corpus scope by source, year range, genre, and tags. Results stay in sync with the main workspace and saved corpus sets."
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                if sidebar.hasAnyMetadataFilterInput {
                    Button(t("清除筛选", "Clear Filters")) {
                        sidebar.clearMetadataFilters()
                        viewModel.applyMetadataFilterState(.empty)
                    }
                }
            }

            metadataSourceField

            HStack(spacing: 12) {
                metadataYearFromField
                metadataYearToField
            }

            metadataYearShortcutRow

            HStack(spacing: 12) {
                metadataGenreField
                metadataTagsField
            }

            HStack(spacing: 10) {
                Text(viewModel.scene.metadataFilterSummary ?? t("未应用筛选条件", "No filters applied"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("·")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text("\(t("匹配语料", "Matching Corpora")) \(viewModel.scene.corpora.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                integrityChip(
                    title: "缺年份 \(viewModel.scene.integritySummary.missingYearCount)",
                    systemImage: "calendar.badge.exclamationmark"
                )
                integrityChip(
                    title: "缺体裁 \(viewModel.scene.integritySummary.missingGenreCount)",
                    systemImage: "text.book.closed"
                )
                integrityChip(
                    title: "缺标签 \(viewModel.scene.integritySummary.missingTagsCount)",
                    systemImage: "tag.slash"
                )
                Spacer(minLength: 0)
            }
        }
        .padding(18)
        .frame(width: 460, alignment: .topLeading)
    }

    private var utilityStatusView: some View {
        Group {
            if let importProgress = viewModel.scene.importProgress {
                HStack(spacing: 8) {
                    ProgressView(value: importProgress)
                        .frame(width: 140)
                    Text(viewModel.scene.importDetail ?? viewModel.scene.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(viewModel.scene.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    var cleaningToolbarTitle: String {
        viewModel.scene.selectedCorpusIDs.count > 1
            ? t("批量清洗", "Clean Selected")
            : t("重新清洗", "Re-clean")
    }

    var cleaningToolbarAction: LibraryManagementAction {
        viewModel.scene.selectedCorpusIDs.count > 1 ? .cleanSelectedCorpora : .cleanSelectedCorpus
    }

    var canTriggerCleaning: Bool {
        viewModel.scene.content.mode == .corpora
            && (
                !viewModel.scene.selectedCorpusIDs.isEmpty
                || viewModel.scene.selectedCorpusID != nil
            )
    }

    private func filterChip(_ chip: LibraryManagementFilterChipSceneItem) -> some View {
        Label(chip.title, systemImage: chip.systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private func integrityChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: Capsule())
    }

    private func cleaningSummaryChip(title: String, count: Int, tint: Color) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(count)")
                .monospacedDigit()
        }
        .font(.caption)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private var metadataSourceField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("来源", "Source"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(t("来源筛选", "Filter source"), text: $sidebar.metadataSourceQuery)
                    .textFieldStyle(.roundedBorder)
                suggestionMenu(
                    symbol: "list.bullet",
                    primaryTitle: t("常用来源", "Common Sources"),
                    primaryItems: sidebar.metadataSourcePresetLabels,
                    secondaryTitle: t("最近使用", "Recent Sources"),
                    secondaryItems: sidebar.metadataRecentSourceMenuLabels
                ) { value in
                    sidebar.applyMetadataSourcePreset(value)
                }
            }
        }
    }

    private var metadataYearFromField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("起始年份", "From year"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(t("起始年份", "From year"), text: $sidebar.metadataYearFromQuery)
                    .textFieldStyle(.roundedBorder)
                suggestionMenu(
                    symbol: "calendar",
                    primaryTitle: t("候选年份", "Suggested Years"),
                    primaryItems: sidebar.metadataSuggestedYearLabels
                ) { value in
                    sidebar.applyMetadataYearSuggestion(value, isLowerBound: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataYearToField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("结束年份", "To year"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                TextField(t("结束年份", "To year"), text: $sidebar.metadataYearToQuery)
                    .textFieldStyle(.roundedBorder)
                suggestionMenu(
                    symbol: "calendar",
                    primaryTitle: t("候选年份", "Suggested Years"),
                    primaryItems: sidebar.metadataSuggestedYearLabels
                ) { value in
                    sidebar.applyMetadataYearSuggestion(value, isLowerBound: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataGenreField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("体裁", "Genre"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(t("体裁筛选", "Filter genre"), text: $sidebar.metadataGenreQuery)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataTagsField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(t("标签", "Tags"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(t("标签筛选", "Filter tags"), text: $sidebar.metadataTagsQuery)
                .textFieldStyle(.roundedBorder)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metadataYearShortcutRow: some View {
        HStack(spacing: 8) {
            ForEach(sidebar.metadataYearRangeShortcuts) { shortcut in
                Button(shortcut.kind.title(in: languageMode)) {
                    sidebar.applyMetadataYearRangeShortcut(shortcut)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            Spacer(minLength: 0)
        }
    }

    private func suggestionMenu(
        symbol: String,
        primaryTitle: String,
        primaryItems: [String],
        secondaryTitle: String? = nil,
        secondaryItems: [String] = [],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        Menu {
            if !primaryItems.isEmpty {
                Section(primaryTitle) {
                    ForEach(primaryItems, id: \.self) { item in
                        Button(item) {
                            onSelect(item)
                        }
                    }
                }
            }

            if let secondaryTitle, !secondaryItems.isEmpty {
                Section(secondaryTitle) {
                    ForEach(secondaryItems, id: \.self) { item in
                        Button(item) {
                            onSelect(item)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .disabled(primaryItems.isEmpty && secondaryItems.isEmpty)
    }
}
