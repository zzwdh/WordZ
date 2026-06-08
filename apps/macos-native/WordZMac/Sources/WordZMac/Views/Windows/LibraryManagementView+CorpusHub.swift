import SwiftUI

extension LibraryManagementView {
    var libraryHubHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(t("语料库中心", "Corpus Hub"))
                    .font(.title3.weight(.semibold))
                Text(libraryHubSubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                if let importProgress = viewModel.scene.importProgress {
                    ProgressView(value: importProgress)
                        .frame(width: 96)
                        .accessibilityLabel(t("导入进度", "Import progress"))
                }

                Button {
                    onAction(.showCorpusBuilder)
                } label: {
                    Label(t("导入视图", "Import View"), systemImage: "tray.and.arrow.down")
                }
                .controlSize(.small)

                Button {
                    onAction(.importPaths)
                } label: {
                    Label(t("添加文件", "Add Files"), systemImage: "plus")
                }
                .controlSize(.small)
                .adaptiveGlassButtonStyle(prominent: true)

                if !viewModel.scene.overflowActions.isEmpty {
                    libraryHubOverflowMenu
                }
            }
        }
    }

    var libraryHubOverviewBand: some View {
        HStack(spacing: 12) {
            lightweightMetric(
                title: t("可见", "Visible"),
                value: "\(viewModel.scene.integritySummary.visibleCorpusCount)"
            )
            lightweightMetric(
                title: t("可用度", "Readiness"),
                value: viewModel.scene.readinessSummary.averageScoreText
            )
            lightweightMetric(
                title: t("元数据", "Metadata"),
                value: viewModel.scene.metadataStudio.completionText
            )
            lightweightMetric(
                title: t("参照", "Reference"),
                value: defaultReferenceCountText
            )

            Spacer(minLength: 12)

            if viewModel.scene.autoCleaningSummary.pendingCount > 0 {
                lightweightStatus(
                    t("待清洗 \(viewModel.scene.autoCleaningSummary.pendingCount)", "Pending \(viewModel.scene.autoCleaningSummary.pendingCount)"),
                    systemImage: "clock",
                    tint: .orange
                )
            }

            let missingMetadataCount = viewModel.scene.integritySummary.missingYearCount
                + viewModel.scene.integritySummary.missingGenreCount
                + viewModel.scene.integritySummary.missingTagsCount
            if missingMetadataCount > 0 {
                lightweightStatus(
                    t("缺元数据 \(missingMetadataCount)", "Missing metadata \(missingMetadataCount)"),
                    systemImage: "tag.slash",
                    tint: .secondary
                )
            }

            libraryReadinessButton
            metadataStudioButton
            if viewModel.scene.metadataFilterSummary != nil || !viewModel.scene.filterChips.isEmpty {
                filterButton
            }
        }
        .font(.caption)
        .lineLimit(1)
        .padding(.vertical, 2)
    }

    var libraryHubEmptyInspector: some View {
        LibraryHubOverviewInspector(
            scene: viewModel.scene,
            onAction: onAction
        )
    }

    private var libraryHubSubtitle: String {
        [
            viewModel.scene.librarySummary,
            viewModel.scene.currentScopeSummary,
            viewModel.scene.statusMessage
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: " · ")
    }

    private var defaultReferenceCount: Int {
        viewModel.scene.corpora.filter { corpus in
            corpus.representedPath.contains("ReferenceCorpora")
                || corpus.representedPath.contains("ToRCH2014")
                || corpus.title.localizedCaseInsensitiveContains("ToRCH2014")
        }.count
    }

    private var defaultReferenceCountText: String {
        defaultReferenceCount == 0 ? "—" : "\(defaultReferenceCount)"
    }

    private var libraryHubOverflowMenu: some View {
        Menu {
            ForEach(viewModel.scene.overflowActions) { item in
                Button(item.title) {
                    onAction(item.action)
                }
            }
        } label: {
            Label(t("更多", "More"), systemImage: "ellipsis.circle")
        }
        .controlSize(.small)
        .adaptiveGlassButtonStyle()
    }

    private func lightweightMetric(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private func lightweightStatus(
        _ title: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        Label(title, systemImage: systemImage)
        .font(.caption)
        .foregroundStyle(tint)
        .accessibilityElement(children: .combine)
    }
}
