import Foundation

@MainActor
extension LibraryManagementViewModel {
    func makeReadinessScene(
        for corpus: LibraryCorpusItem,
        languageMode: AppLanguageMode
    ) -> LibraryCorpusReadinessSceneModel {
        var score = 100
        var issues: [String] = []

        if corpus.cleaningStatus == .pending {
            score -= 30
            issues.append(wordZText("待自动清洗", "Needs auto-cleaning", mode: languageMode))
        }
        if corpus.metadata.sourceLabel.isEmpty {
            score -= 8
            issues.append(wordZText("缺来源", "Missing source", mode: languageMode))
        }
        if corpus.metadata.yearLabel.isEmpty {
            score -= 10
            issues.append(wordZText("缺年份", "Missing year", mode: languageMode))
        }
        if corpus.metadata.genreLabel.isEmpty {
            score -= 10
            issues.append(wordZText("缺体裁", "Missing genre", mode: languageMode))
        }
        if corpus.metadata.tags.isEmpty {
            score -= 10
            issues.append(wordZText("缺标签", "Missing tags", mode: languageMode))
        }
        if corpus.representedPath.isEmpty {
            score -= 5
            issues.append(wordZText("缺原始路径", "Missing original path", mode: languageMode))
        }

        let clampedScore = max(0, min(100, score))
        let level: LibraryCorpusReadinessLevel
        let title: String
        let detail: String
        if clampedScore >= 85 {
            level = .ready
            title = wordZText("可分析", "Ready", mode: languageMode)
            detail = wordZText("清洗和元数据状态良好", "Cleaning and metadata are in good shape", mode: languageMode)
        } else if clampedScore >= 60 {
            level = .attention
            title = wordZText("需补强", "Needs Attention", mode: languageMode)
            detail = issues.prefix(2).joined(separator: " · ")
        } else {
            level = .blocked
            title = wordZText("先整理", "Prepare First", mode: languageMode)
            detail = issues.prefix(3).joined(separator: " · ")
        }

        return LibraryCorpusReadinessSceneModel(
            level: level,
            title: title,
            scoreText: "\(clampedScore)%",
            detailText: detail.isEmpty ? title : detail,
            issueTitles: issues
        )
    }

    func makeReadinessSummary(
        visibleCorpora: [LibraryCorpusItem],
        languageMode: AppLanguageMode
    ) -> LibraryReadinessSummarySceneModel {
        guard !visibleCorpora.isEmpty else { return .empty }

        let readiness = visibleCorpora.map {
            makeReadinessScene(for: $0, languageMode: languageMode)
        }
        let scores = readiness.compactMap { Int($0.scoreText.dropLast()) }
        let averageScore = scores.isEmpty ? 0 : scores.reduce(0, +) / scores.count
        let pendingCleaningCount = visibleCorpora.filter { $0.cleaningStatus == .pending }.count
        let missingMetadataCount = visibleCorpora.filter {
            $0.metadata.sourceLabel.isEmpty
                || $0.metadata.yearLabel.isEmpty
                || $0.metadata.genreLabel.isEmpty
                || $0.metadata.tags.isEmpty
        }.count

        let actionSummary: String
        if pendingCleaningCount > 0 {
            actionSummary = String(
                format: wordZText("优先清洗 %d 条待处理语料", "Clean %d pending corpora first", mode: languageMode),
                pendingCleaningCount
            )
        } else if missingMetadataCount > 0 {
            actionSummary = String(
                format: wordZText("补齐 %d 条语料的元数据", "Complete metadata for %d corpora", mode: languageMode),
                missingMetadataCount
            )
        } else {
            actionSummary = wordZText("当前范围可直接进入分析", "Current scope is ready for analysis", mode: languageMode)
        }

        return LibraryReadinessSummarySceneModel(
            readyCount: readiness.filter { $0.level == .ready }.count,
            attentionCount: readiness.filter { $0.level == .attention }.count,
            blockedCount: readiness.filter { $0.level == .blocked }.count,
            averageScoreText: "\(averageScore)%",
            actionSummaryText: actionSummary
        )
    }

    func makeMetadataStudioScene(
        visibleCorpora: [LibraryCorpusItem],
        selectedCorpusCount: Int,
        languageMode: AppLanguageMode
    ) -> LibraryMetadataStudioSceneModel {
        guard !visibleCorpora.isEmpty else { return .empty }

        let completeCount = visibleCorpora.filter {
            !$0.metadata.sourceLabel.isEmpty
                && !$0.metadata.yearLabel.isEmpty
                && !$0.metadata.genreLabel.isEmpty
                && !$0.metadata.tags.isEmpty
        }.count
        let completion = (completeCount * 100) / max(visibleCorpora.count, 1)
        let actionHint = selectedCorpusCount > 1
            ? wordZText("可直接批量编辑所选语料", "Batch-edit the selected corpora", mode: languageMode)
            : wordZText("选择多条语料后可批量补齐", "Select multiple corpora to complete metadata in bulk", mode: languageMode)

        return LibraryMetadataStudioSceneModel(
            visibleCorpusCount: visibleCorpora.count,
            selectedCorpusCount: selectedCorpusCount,
            completeMetadataCount: completeCount,
            missingYearCount: visibleCorpora.filter { $0.metadata.yearLabel.isEmpty }.count,
            missingGenreCount: visibleCorpora.filter { $0.metadata.genreLabel.isEmpty }.count,
            missingTagsCount: visibleCorpora.filter { $0.metadata.tags.isEmpty }.count,
            completionText: "\(completion)%",
            actionHintText: actionHint
        )
    }
}
