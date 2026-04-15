import Foundation

extension KeywordSceneBuilder {
    func buildRows(
        result: KeywordSuiteResult?,
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        primarySavedList: KeywordSavedList?,
        secondarySavedList: KeywordSavedList?,
        savedLists: [KeywordSavedList]
    ) -> KeywordBuildRowsPayload {
        switch activeTab {
        case .words:
            return KeywordBuildRowsPayload(
                rows: keywordRows(result?.words ?? []),
                emptyTitle: wordZText("尚未生成关键词结果", "No keyword results yet", mode: .system),
                emptyMessage: wordZText(
                    "选择 Focus / Reference 并运行分析，结果会显示单词级关键词。",
                    "Choose focus/reference corpora and run the suite to inspect word keywords.",
                    mode: .system
                )
            )
        case .terms:
            return KeywordBuildRowsPayload(
                rows: keywordRows(result?.terms ?? []),
                emptyTitle: wordZText("尚未生成术语结果", "No term results yet", mode: .system),
                emptyMessage: wordZText(
                    "术语页会从 2-5 gram 候选中筛出符合词法规则的多词术语。",
                    "Terms are filtered from 2-5 gram candidates using lexical rules.",
                    mode: .system
                )
            )
        case .ngrams:
            return KeywordBuildRowsPayload(
                rows: keywordRows(result?.ngrams ?? []),
                emptyTitle: wordZText("尚未生成 N-gram 结果", "No N-gram results yet", mode: .system),
                emptyMessage: wordZText(
                    "N-grams 会显示句内 2-5 gram 连续序列的 keyness 结果。",
                    "N-grams show sentence-bounded 2-5 gram keyness results.",
                    mode: .system
                )
            )
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                return KeywordBuildRowsPayload(
                    rows: pairwiseDiffRows(left: primarySavedList, right: secondarySavedList),
                    emptyTitle: wordZText("尚未选择可比词表", "Choose two saved lists", mode: .system),
                    emptyMessage: wordZText(
                        "先保存当前结果，再在这里选择两份词表做差异对比。",
                        "Save current rows first, then choose two saved lists for pairwise diff.",
                        mode: .system
                    )
                )
            case .keywordDatabase:
                return KeywordBuildRowsPayload(
                    rows: keywordDatabaseRows(lists: savedLists),
                    emptyTitle: wordZText("尚未保存关键词词表", "No saved keyword lists yet", mode: .system),
                    emptyMessage: wordZText(
                        "保存几份关键词词表后，这里会汇总 coverage、平均显著性和平均效应值。",
                        "After saving several lists, this view aggregates coverage, mean keyness, and mean effect size.",
                        mode: .system
                    )
                )
            }
        }
    }

    func keywordRows(_ rows: [KeywordSuiteRow]) -> [KeywordBuildRow] {
        rows.map { row in
            KeywordBuildRow(
                id: row.id,
                kind: .keyword,
                item: row.item,
                direction: row.direction,
                focusFrequency: row.focusFrequency,
                referenceFrequency: row.referenceFrequency,
                focusNormFrequency: row.focusNormalizedFrequency,
                referenceNormFrequency: row.referenceNormalizedFrequency,
                keyness: row.keynessScore,
                logRatio: row.logRatio,
                pValue: row.pValue,
                focusRange: row.focusRange,
                referenceRange: row.referenceRange,
                example: row.example,
                diffStatus: nil,
                leftRank: nil,
                rightRank: nil,
                logRatioDelta: 0,
                coverageCount: 0,
                coverageRate: 0,
                meanKeyness: 0,
                meanAbsLogRatio: 0,
                lastSeenAt: ""
            )
        }
    }

    func pairwiseDiffRows(
        left: KeywordSavedList?,
        right: KeywordSavedList?
    ) -> [KeywordBuildRow] {
        guard let left, let right, left.id != right.id else { return [] }
        let leftRows = Dictionary(uniqueKeysWithValues: left.rows.enumerated().map { ($0.element.item, ($0.offset + 1, $0.element)) })
        let rightRows = Dictionary(uniqueKeysWithValues: right.rows.enumerated().map { ($0.element.item, ($0.offset + 1, $0.element)) })
        let items = Set(leftRows.keys).union(rightRows.keys)

        return items.map { item in
            let leftBundle = leftRows[item]
            let rightBundle = rightRows[item]
            let status: KeywordSavedListDiffRow.DiffStatus
            switch (leftBundle != nil, rightBundle != nil) {
            case (true, false):
                status = .onlyLeft
            case (false, true):
                status = .onlyRight
            default:
                status = .shared
            }
            let delta = (leftBundle?.1.logRatio ?? 0) - (rightBundle?.1.logRatio ?? 0)

            return KeywordBuildRow(
                id: [left.id, right.id, item].joined(separator: "::"),
                kind: .pairwiseDiff,
                item: item,
                direction: nil,
                focusFrequency: 0,
                referenceFrequency: 0,
                focusNormFrequency: 0,
                referenceNormFrequency: 0,
                keyness: 0,
                logRatio: 0,
                pValue: 0,
                focusRange: 0,
                referenceRange: 0,
                example: "",
                diffStatus: status,
                leftRank: leftBundle?.0,
                rightRank: rightBundle?.0,
                logRatioDelta: delta,
                coverageCount: 0,
                coverageRate: 0,
                meanKeyness: 0,
                meanAbsLogRatio: abs(delta),
                lastSeenAt: max(left.updatedAt, right.updatedAt)
            )
        }
    }

    func keywordDatabaseRows(lists: [KeywordSavedList]) -> [KeywordBuildRow] {
        guard !lists.isEmpty else { return [] }

        struct Aggregate {
            var count = 0
            var totalAbsKeyness = 0.0
            var totalAbsLogRatio = 0.0
            var lastSeenAt = ""
        }

        var aggregates: [String: Aggregate] = [:]
        for list in lists {
            for row in list.rows {
                var aggregate = aggregates[row.item, default: Aggregate()]
                aggregate.count += 1
                aggregate.totalAbsKeyness += abs(row.keynessScore)
                aggregate.totalAbsLogRatio += abs(row.logRatio)
                aggregate.lastSeenAt = max(aggregate.lastSeenAt, list.updatedAt)
                aggregates[row.item] = aggregate
            }
        }

        return aggregates.map { item, aggregate in
            let coverageRate = Double(aggregate.count) / Double(max(lists.count, 1))
            let meanKeyness = aggregate.totalAbsKeyness / Double(max(aggregate.count, 1))
            let meanAbsLogRatio = aggregate.totalAbsLogRatio / Double(max(aggregate.count, 1))

            return KeywordBuildRow(
                id: item,
                kind: .keywordDatabase,
                item: item,
                direction: nil,
                focusFrequency: 0,
                referenceFrequency: 0,
                focusNormFrequency: 0,
                referenceNormFrequency: 0,
                keyness: 0,
                logRatio: 0,
                pValue: 0,
                focusRange: 0,
                referenceRange: 0,
                example: "",
                diffStatus: nil,
                leftRank: nil,
                rightRank: nil,
                logRatioDelta: 0,
                coverageCount: aggregate.count,
                coverageRate: coverageRate,
                meanKeyness: meanKeyness,
                meanAbsLogRatio: meanAbsLogRatio,
                lastSeenAt: aggregate.lastSeenAt
            )
        }
    }
}

struct KeywordBuildRowsPayload {
    let rows: [KeywordBuildRow]
    let emptyTitle: String
    let emptyMessage: String
}

struct KeywordBuildRow {
    let id: String
    let kind: KeywordSceneRowKind
    let item: String
    let direction: KeywordRowDirection?
    let focusFrequency: Int
    let referenceFrequency: Int
    let focusNormFrequency: Double
    let referenceNormFrequency: Double
    let keyness: Double
    let logRatio: Double
    let pValue: Double
    let focusRange: Int
    let referenceRange: Int
    let example: String
    let diffStatus: KeywordSavedListDiffRow.DiffStatus?
    let leftRank: Int?
    let rightRank: Int?
    let logRatioDelta: Double
    let coverageCount: Int
    let coverageRate: Double
    let meanKeyness: Double
    let meanAbsLogRatio: Double
    let lastSeenAt: String

    var primaryKeynessSortValue: Double {
        switch kind {
        case .keyword:
            return abs(keyness)
        case .pairwiseDiff:
            return abs(logRatioDelta)
        case .keywordDatabase:
            return meanKeyness
        }
    }

    var primaryAbsLogRatioSortValue: Double {
        switch kind {
        case .keyword:
            return abs(logRatio)
        case .pairwiseDiff:
            return abs(logRatioDelta)
        case .keywordDatabase:
            return meanAbsLogRatio
        }
    }
}
