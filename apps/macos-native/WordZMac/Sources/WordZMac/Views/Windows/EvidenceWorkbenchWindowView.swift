import SwiftUI

struct EvidenceWorkbenchWindowView: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @ObservedObject private var workbench: EvidenceWorkbenchViewModel
    @State private var showsSourceSummary = false

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
                    onAction: handle
                )
            } detail: {
                EvidenceWorkbenchDetailPanel(
                    workbench: workbench,
                    onAction: handle
                )
                .padding(20)
            }
            .navigationSplitViewStyle(.balanced)
        }
        .adaptiveWindowScaffold(for: .evidenceWorkbench)
        .bindWindowRoute(.evidenceWorkbench, titleProvider: { mode in
            wordZText("摘录篮", "Excerpt Tray", mode: mode)
        })
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
                    Text(t("摘录篮", "Excerpt Tray"))
                        .font(.title3.weight(.semibold))
                    Text(
                        String(
                            format: t(
                                "已暂存 %d 条摘录；当前显示 %d 条。",
                                "%d excerpts saved; %d currently visible."
                            ),
                            workbench.items.count,
                            workbench.filteredItems.count
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                reviewFilterPicker

                if workbench.hasActiveNarrowingFilters {
                    Button {
                        workbench.clearFilters()
                    } label: {
                        Label(t("清除筛选", "Clear Filters"), systemImage: "xmark.circle")
                    }
                    .help(t("显示全部摘录", "Show all excerpts"))
                }

                handoffSummaryToggle
                copySaveMenu
            }

            if showsSourceSummary || workbench.hasMetadataGapsInVisibleKeptItems {
                handoffStatusStrip
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

        }
        .padding(20)
    }

    private var reviewFilterPicker: some View {
        Picker(
            t("显示", "Show"),
            selection: $workbench.reviewFilter
        ) {
            ForEach(EvidenceReviewFilter.allCases) { filter in
                Text(filter.title(in: languageMode))
                    .tag(filter)
            }
        }
        .pickerStyle(.menu)
        .frame(width: 128)
    }

    private var handoffSummaryToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                showsSourceSummary.toggle()
            }
        } label: {
            Label(
                t("来源检查", "Source Check"),
                systemImage: workbench.hasMetadataGapsInVisibleKeptItems
                    ? "exclamationmark.triangle"
                    : "checkmark.seal"
            )
        }
        .help(t("显示或隐藏来源检查", "Show or hide source checks"))
    }

    private var copySaveMenu: some View {
        Menu {
            Button(t("复制所选引文", "Copy Selected Citation")) {
                guard let itemID = workbench.selectedItem?.id else { return }
                handle(.copyCitation(itemID: itemID))
            }
            .disabled(workbench.selectedItem == nil)

            Button(t("保存保留摘录为文本…", "Save Kept Excerpts as Text…")) {
                handle(.exportMarkdown)
            }
            .disabled(!workbench.hasVisibleKeptItems)
        } label: {
            Label(t("复制/保存", "Copy/Save"), systemImage: "square.and.arrow.up")
        }
    }

    private var handoffStatusStrip: some View {
        HStack(spacing: 12) {
            handoffStatusMetric(
                systemImage: "line.3.horizontal.decrease.circle",
                title: t("保存范围", "Save Scope"),
                value: workbench.exportScopeSummary(in: languageMode)
            )

            Divider()
                .frame(height: 24)

            handoffStatusMetric(
                systemImage: "quote.opening",
                title: t("引文文本", "Citation Text"),
                value: workbench.citationReadinessSummary(in: languageMode)
            )

            Divider()
                .frame(height: 24)

            handoffStatusMetric(
                systemImage: workbench.hasMetadataGapsInVisibleKeptItems ? "exclamationmark.triangle" : "checkmark.seal",
                title: t("来源元数据", "Source Metadata"),
                value: workbench.metadataReadinessSummary(in: languageMode),
                isWarning: workbench.hasMetadataGapsInVisibleKeptItems
            )
        }
        .font(.caption)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private func handoffStatusMetric(
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

    private func handle(_ action: EvidenceWorkbenchWindowAction) {
        switch action {
        case .updateReviewStatus(let itemID, let status):
            Task { await workspace.updateEvidenceReviewStatus(itemID: itemID, reviewStatus: status) }
        case .exportMarkdown:
            Task { await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .evidenceWorkbench) }
        case .saveDetails:
            Task { await workspace.saveSelectedEvidenceDetails() }
        case .deleteItem(let itemID):
            Task { await workspace.deleteEvidenceItem(itemID) }
        case .copyCitation(let itemID):
            Task { await workspace.copyEvidenceCitation(itemID: itemID) }
        }
    }
}
