import Foundation

@MainActor
extension LibraryManagementViewModel {
    func buildFilterChips(
        searchQuery: String,
        metadataFilterSummary: String?,
        integritySummary: LibraryIntegritySummarySceneModel
    ) -> [LibraryManagementFilterChipSceneItem] {
        var chips: [LibraryManagementFilterChipSceneItem] = []

        if !searchQuery.isEmpty {
            chips.append(
                LibraryManagementFilterChipSceneItem(
                    id: "search-query",
                    title: "搜索：\(searchQuery)",
                    systemImage: "magnifyingglass"
                )
            )
        }

        if let metadataFilterSummary, !metadataFilterSummary.isEmpty {
            chips.append(
                LibraryManagementFilterChipSceneItem(
                    id: "metadata-filter-summary",
                    title: metadataFilterSummary,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            )
        }
        if integritySummary.missingYearCount > 0 {
            chips.append(
                .init(
                    id: "missing-year",
                    title: "缺年份 \(integritySummary.missingYearCount)",
                    systemImage: "calendar.badge.exclamationmark"
                )
            )
        }
        if integritySummary.missingGenreCount > 0 {
            chips.append(
                .init(
                    id: "missing-genre",
                    title: "缺体裁 \(integritySummary.missingGenreCount)",
                    systemImage: "text.book.closed"
                )
            )
        }
        if integritySummary.missingTagsCount > 0 {
            chips.append(
                .init(
                    id: "missing-tags",
                    title: "缺标签 \(integritySummary.missingTagsCount)",
                    systemImage: "tag.slash"
                )
            )
        }

        return chips
    }

    func buildOverflowActions() -> [LibraryManagementOverflowActionSceneItem] {
        [
            .init(id: "refresh", title: "刷新", action: .refresh),
            .init(id: "create-folder", title: "新建文件夹", action: .createFolder),
            .init(id: "backup-library", title: "备份", action: .backupLibrary),
            .init(id: "restore-library", title: "恢复", action: .restoreLibrary),
            .init(id: "repair-library", title: "修复", action: .repairLibrary)
        ]
    }

    func makeImportSummaryScene(
        result: LibraryImportResult,
        languageMode: AppLanguageMode = WordZLocalization.shared.effectiveMode
    ) -> LibraryImportSummarySceneModel {
        LibraryImportSummarySceneModel(
            id: UUID().uuidString,
            title: wordZText("导入完成", "Import Completed", mode: languageMode),
            subtitle: wordZText("自动清洗摘要", "Auto-Cleaning Summary", mode: languageMode),
            importedCountText: "\(result.importedCount)",
            skippedCountText: "\(result.skippedCount)",
            cleanedCountText: "\(result.cleaningSummary.cleanedCount)",
            changedCountText: "\(result.cleaningSummary.changedCount)",
            ruleHitsSummaryText: result.cleaningSummary.ruleHits.isEmpty
                ? wordZText("未命中清洗规则", "No cleaning rules hit", mode: languageMode)
                : result.cleaningSummary.ruleHits.prefix(3)
                    .map { "\($0.title(in: languageMode)) \($0.count)" }
                    .joined(separator: " · "),
            firstFailureText: result.failureItems.first.map {
                "\($0.fileName) (\($0.reason))"
            } ?? wordZText("无", "None", mode: languageMode)
        )
    }

    func importDetailText(_ snapshot: LibraryImportProgressSnapshot) -> String {
        switch snapshot.phase {
        case .preparing:
            return "正在准备导入…"
        case .importing:
            let name = snapshot.currentName.isEmpty ? "当前文件" : snapshot.currentName
            return "正在导入 \(name) · \(snapshot.completedCount) / \(snapshot.totalCount)"
        case .committing:
            return "正在写入语料库索引…"
        case .completed:
            return "导入完成"
        }
    }
}
