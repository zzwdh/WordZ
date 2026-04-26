import SwiftUI

struct EvidenceWorkbenchWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var workbench: EvidenceWorkbenchViewModel
    @State private var showsAdvancedFilters = false

    init(workspace: MainWorkspaceViewModel) {
        self.workspace = workspace
        _workbench = ObservedObject(wrappedValue: workspace.evidenceWorkbench)
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            NavigationSplitView {
                EvidenceWorkbenchSidebarList(
                    workbench: workbench,
                    languageMode: languageMode,
                    onMoveGroup: { groupID, direction in
                        Task { await workspace.moveEvidenceGroup(groupID, direction: direction) }
                    },
                    onReorderGroup: { sourceGroupID, targetGroupID, placement in
                        Task {
                            await workspace.moveEvidenceGroup(
                                sourceGroupID,
                                to: targetGroupID,
                                placement: placement
                            )
                        }
                    },
                    onAssignItemToGroup: { itemID, targetGroupID in
                        Task {
                            await workspace.assignEvidenceItem(
                                itemID,
                                to: targetGroupID
                            )
                        }
                    },
                    onCreateGroupFromItem: { itemID in
                        Task {
                            await workspace.createGroupAndAssignEvidenceItem(
                                itemID,
                                preferredWindowRoute: .evidenceWorkbench
                            )
                        }
                    },
                    onSplitSelectedGroup: {
                        Task { await workspace.splitSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onRenameSelectedGroup: {
                        Task { await workspace.renameSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onMergeSelectedGroup: {
                        Task { await workspace.mergeSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    }
                )
            } detail: {
                EvidenceWorkbenchDetailPanel(
                    workbench: workbench,
                    onUpdateStatus: { itemID, status in
                        Task { await workspace.updateEvidenceReviewStatus(itemID: itemID, reviewStatus: status) }
                    },
                    onMoveSelected: { direction in
                        Task { await workspace.moveSelectedEvidenceItem(direction) }
                    },
                    onExportMarkdown: {
                        Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onExportJSON: {
                        Task { await workspace.exportEvidenceJSON(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onMoveSelectedGroup: { direction in
                        Task { await workspace.moveSelectedEvidenceGroup(direction) }
                    },
                    onSplitSelectedGroup: {
                        Task { await workspace.splitSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onRenameSelectedGroup: {
                        Task { await workspace.renameSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onMergeSelectedGroup: {
                        Task { await workspace.mergeSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    },
                    onSaveDetails: {
                        Task { await workspace.saveSelectedEvidenceDetails() }
                    },
                    onDeleteItem: { itemID in
                        Task { await workspace.deleteEvidenceItem(itemID) }
                    },
                    onCopyCitation: { itemID in
                        Task { await workspace.copyEvidenceCitation(itemID: itemID) }
                    }
                )
                .padding(20)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .adaptiveWindowScaffold(for: .evidenceWorkbench)
        .bindWindowRoute(.evidenceWorkbench, titleProvider: { mode in
            workbench.groupingMode.currentGroupWindowTitle(
                baseTitle: NativeWindowRoute.evidenceWorkbench.title(in: mode),
                group: workbench.selectedGroup(in: mode),
                in: mode
            )
        })
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Button(workbench.groupingMode.moveSelectedGroupTitle(.up, in: languageMode)) {
                        Task { await workspace.moveSelectedEvidenceGroup(.up) }
                    }
                    .disabled(!workbench.canMoveSelectedGroupUp)

                    Button(workbench.groupingMode.moveSelectedGroupTitle(.down, in: languageMode)) {
                        Task { await workspace.moveSelectedEvidenceGroup(.down) }
                    }
                    .disabled(!workbench.canMoveSelectedGroupDown)

                    Divider()

                    Button(workbench.groupingMode.splitSelectedGroupTitle(in: languageMode)) {
                        Task { await workspace.splitSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    }
                    .disabled(!workbench.canSplitSelectedGroup)

                    Button(workbench.groupingMode.renameSelectedGroupTitle(in: languageMode)) {
                        Task { await workspace.renameSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    }
                    .disabled(!(workbench.groupingMode.supportsItemAssignment && workbench.selectedGroup(in: languageMode) != nil))

                    Button(workbench.groupingMode.mergeSelectedGroupTitle(in: languageMode)) {
                        Task { await workspace.mergeSelectedEvidenceGroup(preferredWindowRoute: .evidenceWorkbench) }
                    }
                    .disabled(!(workbench.groupingMode.supportsItemAssignment && workbench.selectedGroup(in: languageMode) != nil))

                    Divider()

                    Button(t("导出摘录", "Export Clips")) {
                        Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
                    }
                    .disabled(!workbench.hasVisibleKeptItems)

                    Button(t("导出 JSON", "Export JSON")) {
                        Task { await workspace.exportEvidenceJSON(preferredWindowRoute: .evidenceWorkbench) }
                    }
                    .disabled(workbench.filteredItems.isEmpty)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.secondary)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(workbench.groupingMode.currentGroupTitle(in: languageMode))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(
                                workbench.groupingMode.currentGroupToolbarSummary(
                                    group: workbench.selectedGroup(in: languageMode),
                                    in: languageMode
                                )
                            )
                            .lineLimit(1)
                        }
                    }
                    .frame(minWidth: 180, alignment: .leading)
                }
                .help(
                    workbench.groupingMode.currentGroupTitle(in: languageMode) +
                        "\n" +
                        workbench.groupingMode.currentGroupToolbarSummary(
                            group: workbench.selectedGroup(in: languageMode),
                            in: languageMode
                        )
                )
            }
        }
        .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .evidenceWorkbench))
        .task {
            await workspace.initializeIfNeeded()
            await workspace.refreshEvidenceItems()
        }
        .frame(minWidth: 980, minHeight: 680)
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("摘录", "Clips"))
                        .font(.title3.weight(.semibold))
                    Text(
                        String(
                            format: t(
                                "当前筛选下共有 %d 条证据，已组织为 %d 组。",
                                "%d evidence items are currently visible across %d groups."
                            ),
                            workbench.filteredItems.count,
                            workbench.groupedItems(in: languageMode).count
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Picker(
                    t("组织方式", "Grouping"),
                    selection: $workbench.groupingMode
                ) {
                    ForEach(EvidenceWorkbenchGroupingMode.allCases) { grouping in
                        Text(grouping.title(in: languageMode))
                            .tag(grouping)
                    }
                }
                .pickerStyle(.menu)

                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showsAdvancedFilters.toggle()
                    }
                } label: {
                    Label(t("筛选", "Filters"), systemImage: "line.3.horizontal.decrease.circle")
                }
                .help(t("显示或隐藏高级筛选", "Show or hide advanced filters"))

                Button(t("导出摘录", "Export Clips")) {
                    Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
                }
                .disabled(!workbench.hasVisibleKeptItems)

                Button(t("导出 JSON", "Export JSON")) {
                    Task { await workspace.exportEvidenceJSON(preferredWindowRoute: .evidenceWorkbench) }
                }
                .disabled(workbench.filteredItems.isEmpty)
            }

            dossierStatusStrip

            if showsAdvancedFilters || workbench.hasActiveNarrowingFilters {
                advancedFilterSection
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
    }

    private var advancedFilterSection: some View {
        HStack(spacing: 10) {
            Picker(
                t("审校状态", "Review Status"),
                selection: $workbench.reviewFilter
            ) {
                ForEach(EvidenceReviewFilter.allCases) { filter in
                    Text(filter.title(in: languageMode))
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 128)

            Picker(
                t("来源", "Source"),
                selection: $workbench.sourceFilter
            ) {
                ForEach(EvidenceSourceFilter.allCases) { filter in
                    Text(filter.title(in: languageMode))
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 136)

            Picker(
                t("情感", "Sentiment"),
                selection: $workbench.sentimentFilter
            ) {
                ForEach(EvidenceSentimentFilter.allCases) { filter in
                    Text(filter.title(in: languageMode))
                        .tag(filter)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 136)

            TextField(t("标签筛选", "Filter Tags"), text: $workbench.tagFilterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 150)

            TextField(t("语料筛选", "Filter Corpus"), text: $workbench.corpusFilterQuery)
                .textFieldStyle(.roundedBorder)
                .frame(width: 170)

            if workbench.hasActiveNarrowingFilters {
                Button {
                    workbench.clearFilters()
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .help(t("清除筛选", "Clear Filters"))
            }

            Spacer()
        }
    }

    private var dossierStatusStrip: some View {
        HStack(spacing: 12) {
            dossierStatusMetric(
                systemImage: "line.3.horizontal.decrease.circle",
                title: t("范围", "Scope"),
                value: workbench.exportScopeSummary(in: languageMode)
            )

            Divider()
                .frame(height: 24)

            dossierStatusMetric(
                systemImage: "quote.opening",
                title: t("引用", "Citation"),
                value: workbench.citationReadinessSummary(in: languageMode)
            )

            Divider()
                .frame(height: 24)

            dossierStatusMetric(
                systemImage: workbench.hasMetadataGapsInVisibleKeptItems ? "exclamationmark.triangle" : "checkmark.seal",
                title: t("元数据", "Metadata"),
                value: workbench.metadataReadinessSummary(in: languageMode),
                isWarning: workbench.hasMetadataGapsInVisibleKeptItems
            )
        }
        .font(.caption)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func dossierStatusMetric(
        systemImage: String,
        title: String,
        value: String,
        isWarning: Bool = false
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .foregroundStyle(isWarning ? .orange : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .help(title + ": " + value)
    }

    private func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
