import Foundation
import WordZShared

struct LibraryManagementCorpusSceneMetrics {
    let corpora: [LibraryManagementCorpusSceneItem]
    let readinessByCorpusID: [String: LibraryCorpusReadinessSceneModel]
    let autoCleaningSummary: LibraryAutoCleaningSummarySceneModel
    let integritySummary: LibraryIntegritySummarySceneModel
    let readinessSummary: LibraryReadinessSummarySceneModel
    let metadataStudio: LibraryMetadataStudioSceneModel
}

@MainActor
extension LibraryManagementViewModel {
    func buildCorpusSceneMetrics(
        visibleCorpora: [LibraryCorpusItem],
        selectedCorpusIDs: Set<String>,
        languageMode: AppLanguageMode
    ) -> LibraryManagementCorpusSceneMetrics {
        guard !visibleCorpora.isEmpty else {
            return LibraryManagementCorpusSceneMetrics(
                corpora: [],
                readinessByCorpusID: [:],
                autoCleaningSummary: .empty,
                integritySummary: .empty,
                readinessSummary: .empty,
                metadataStudio: .empty
            )
        }

        var corpora: [LibraryManagementCorpusSceneItem] = []
        corpora.reserveCapacity(visibleCorpora.count)
        var readinessByCorpusID: [String: LibraryCorpusReadinessSceneModel] = [:]
        readinessByCorpusID.reserveCapacity(visibleCorpora.count)

        var cleanedCount = 0
        var pendingCount = 0
        var changedCount = 0
        var readyCount = 0
        var attentionCount = 0
        var blockedCount = 0
        var scoreTotal = 0
        var completeMetadataCount = 0
        var missingMetadataCount = 0
        var missingYearCount = 0
        var missingGenreCount = 0
        var missingTagsCount = 0

        for corpus in visibleCorpora {
            switch corpus.cleaningStatus {
            case .cleaned:
                cleanedCount += 1
            case .pending:
                pendingCount += 1
            case .cleanedWithChanges:
                changedCount += 1
            }

            let hasMissingYear = corpus.metadata.yearLabel.isEmpty
            let hasMissingGenre = corpus.metadata.genreLabel.isEmpty
            let hasMissingTags = corpus.metadata.tags.isEmpty
            let hasMissingSource = corpus.metadata.sourceLabel.isEmpty
            if hasMissingYear { missingYearCount += 1 }
            if hasMissingGenre { missingGenreCount += 1 }
            if hasMissingTags { missingTagsCount += 1 }
            if hasMissingSource || hasMissingYear || hasMissingGenre || hasMissingTags {
                missingMetadataCount += 1
            } else {
                completeMetadataCount += 1
            }

            let readiness = makeReadinessScene(for: corpus, languageMode: languageMode)
            readinessByCorpusID[corpus.id] = readiness
            scoreTotal += Int(readiness.scoreText.dropLast()) ?? 0
            switch readiness.level {
            case .ready:
                readyCount += 1
            case .attention:
                attentionCount += 1
            case .blocked:
                blockedCount += 1
            }

            let cleaningSummary = corpus.cleaningSummary
            corpora.append(
                LibraryManagementCorpusSceneItem(
                    id: corpus.id,
                    title: corpus.name,
                    subtitle: corpus.folderName,
                    sourceType: corpus.sourceType,
                    databaseFileName: corpus.databaseFileDisplayName,
                    representedPath: corpus.representedPath,
                    sourceSummary: corpusSourceSummary(for: corpus, languageMode: languageMode),
                    metadataSummary: corpus.metadata.compactSummary(in: languageMode),
                    readiness: readiness,
                    cleaningStatus: corpus.cleaningStatus,
                    cleaningStatusTitle: corpus.cleaningStatus.title(in: languageMode),
                    cleaningSummary: cleaningSummary?.ruleHitsSummary(in: languageMode, limit: 2)
                        ?? wordZText("尚未执行自动清洗", "Auto-cleaning not run yet", mode: languageMode),
                    isSelected: selectedCorpusIDs.contains(corpus.id),
                    hasMissingYear: hasMissingYear,
                    hasMissingGenre: hasMissingGenre,
                    hasMissingTags: hasMissingTags
                )
            )
        }

        let averageScore = scoreTotal / max(visibleCorpora.count, 1)
        let actionSummary: String
        if pendingCount > 0 {
            actionSummary = String(
                format: wordZText("优先清洗 %d 条待处理语料", "Clean %d pending corpora first", mode: languageMode),
                pendingCount
            )
        } else if missingMetadataCount > 0 {
            actionSummary = String(
                format: wordZText("补齐 %d 条语料的元数据", "Complete metadata for %d corpora", mode: languageMode),
                missingMetadataCount
            )
        } else {
            actionSummary = wordZText("当前范围可直接进入分析", "Current scope is ready for analysis", mode: languageMode)
        }

        let metadataActionHint = selectedCorpusIDs.count > 1
            ? wordZText("可直接批量编辑所选语料", "Batch-edit the selected corpora", mode: languageMode)
            : wordZText("选择多条语料后可批量补齐", "Select multiple corpora to complete metadata in bulk", mode: languageMode)

        return LibraryManagementCorpusSceneMetrics(
            corpora: corpora,
            readinessByCorpusID: readinessByCorpusID,
            autoCleaningSummary: LibraryAutoCleaningSummarySceneModel(
                cleanedCount: cleanedCount,
                pendingCount: pendingCount,
                changedCount: changedCount
            ),
            integritySummary: LibraryIntegritySummarySceneModel(
                visibleCorpusCount: visibleCorpora.count,
                missingYearCount: missingYearCount,
                missingGenreCount: missingGenreCount,
                missingTagsCount: missingTagsCount
            ),
            readinessSummary: LibraryReadinessSummarySceneModel(
                readyCount: readyCount,
                attentionCount: attentionCount,
                blockedCount: blockedCount,
                averageScoreText: "\(averageScore)%",
                actionSummaryText: actionSummary
            ),
            metadataStudio: LibraryMetadataStudioSceneModel(
                visibleCorpusCount: visibleCorpora.count,
                selectedCorpusCount: selectedCorpusIDs.count,
                completeMetadataCount: completeMetadataCount,
                missingYearCount: missingYearCount,
                missingGenreCount: missingGenreCount,
                missingTagsCount: missingTagsCount,
                completionText: "\((completeMetadataCount * 100) / max(visibleCorpora.count, 1))%",
                actionHintText: metadataActionHint
            )
        )
    }

    private func corpusSourceSummary(
        for corpus: LibraryCorpusItem,
        languageMode: AppLanguageMode
    ) -> String {
        let representedPath = corpus.representedPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if representedPath.hasPrefix("wordz://corpus-set/") {
            return wordZText("语料集生成", "Created from corpus set", mode: languageMode)
        }
        if representedPath.isEmpty {
            return corpus.sourceType.lowercased() == "db"
                ? wordZText("内置语料", "Built-in corpus", mode: languageMode)
                : wordZText("导入语料", "Imported corpus", mode: languageMode)
        }

        let fileName = URL(fileURLWithPath: representedPath).lastPathComponent
        guard !fileName.isEmpty else {
            return wordZText("文件导入", "File import", mode: languageMode)
        }
        return String(
            format: wordZText("文件导入：%@", "File import: %@", mode: languageMode),
            fileName
        )
    }
}
