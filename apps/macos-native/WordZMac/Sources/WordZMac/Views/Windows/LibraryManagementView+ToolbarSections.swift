import SwiftUI

extension LibraryManagementView {
    var libraryMetadataToolbarSection: some View {
        NativeWindowSection(title: t("元数据筛选", "Metadata Filters"), subtitle: viewModel.scene.metadataFilterSummary) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    metadataSourceField
                    metadataYearField
                    metadataGenreField
                    metadataTagsField
                    clearFiltersButton
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        metadataSourceField
                        metadataYearField
                    }
                    HStack(spacing: 12) {
                        metadataGenreField
                        metadataTagsField
                        clearFiltersButton
                    }
                }
            }

            HStack(spacing: 12) {
                if let metadataFilterSummary = viewModel.scene.metadataFilterSummary {
                    Label(metadataFilterSummary, systemImage: "line.3.horizontal.decrease.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Label("缺年份 \(viewModel.scene.integritySummary.missingYearCount)", systemImage: "calendar.badge.exclamationmark")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("缺体裁 \(viewModel.scene.integritySummary.missingGenreCount)", systemImage: "text.book.closed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label("缺标签 \(viewModel.scene.integritySummary.missingTagsCount)", systemImage: "tag.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    var libraryActionToolbarSection: some View {
        NativeWindowSection(title: t("操作", "Actions"), subtitle: viewModel.scene.statusMessage) {
            HStack(spacing: 10) {
                Button(t("刷新", "Refresh")) { onAction(.refresh) }
                Button(t("导入语料", "Import Corpora")) { onAction(.importPaths) }
                Button(t("新建文件夹", "New Folder")) { onAction(.createFolder) }
                Button(t("保存当前语料集", "Save Current Corpus Set")) { onAction(.saveCurrentCorpusSet) }
                    .disabled(viewModel.saveableCorpusSetMembers.isEmpty)
                Button(t("备份", "Backup")) { onAction(.backupLibrary) }
                Button(t("恢复", "Restore")) { onAction(.restoreLibrary) }
                Button(t("修复", "Repair")) { onAction(.repairLibrary) }
                Spacer()
                if let importProgress = viewModel.scene.importProgress {
                    ProgressView(value: importProgress)
                        .frame(width: 160)
                    if let importDetail = viewModel.scene.importDetail {
                        Text(importDetail)
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
    }

    private var metadataSourceField: some View {
        TextField(t("来源筛选", "Filter source"), text: $sidebar.metadataSourceQuery)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 120)
    }

    private var metadataYearField: some View {
        TextField(t("年份筛选", "Filter year"), text: $sidebar.metadataYearQuery)
            .textFieldStyle(.roundedBorder)
            .frame(width: 110)
    }

    private var metadataGenreField: some View {
        TextField(t("体裁筛选", "Filter genre"), text: $sidebar.metadataGenreQuery)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 120)
    }

    private var metadataTagsField: some View {
        TextField(t("标签筛选", "Filter tags"), text: $sidebar.metadataTagsQuery)
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 140)
    }

    private var clearFiltersButton: some View {
        Button(t("清除筛选", "Clear Filters")) {
            sidebar.clearMetadataFilters()
            viewModel.applyMetadataFilterState(.empty)
        }
        .disabled(sidebar.metadataFilterState.isEmpty)
    }
}
