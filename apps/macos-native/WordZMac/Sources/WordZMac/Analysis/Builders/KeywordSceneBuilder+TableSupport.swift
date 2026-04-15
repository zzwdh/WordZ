import Foundation

extension KeywordSceneBuilder {
    func buildTable(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        statistic: KeywordStatisticMethod,
        visibleColumns: Set<KeywordColumnKey>,
        sortMode: KeywordSortMode,
        languageMode: AppLanguageMode
    ) -> NativeTableDescriptor {
        let keys = columnKeys(activeTab: activeTab, listMode: listMode)
        return NativeTableDescriptor(
            storageKey: "keyword-\(activeTab.rawValue)-\(listMode.rawValue)",
            columns: keys.map { key in
                NativeTableColumnDescriptor(
                    id: key.rawValue,
                    title: key.title(in: languageMode, statistic: statistic),
                    isVisible: visibleColumns.contains(key),
                    sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                    presentation: presentation(for: key),
                    widthPolicy: widthPolicy(for: key),
                    isPinned: key == .rank || key == .item
                )
            },
            defaultDensity: keys.contains(.example) ? .reading : .standard
        )
    }

    func columnKeys(
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode
    ) -> [KeywordColumnKey] {
        switch activeTab {
        case .words, .terms, .ngrams:
            return [
                .rank, .item, .direction, .focusFrequency, .referenceFrequency,
                .focusNormFrequency, .referenceNormFrequency, .keyness, .logRatio,
                .pValue, .focusRange, .referenceRange, .example
            ]
        case .lists:
            switch listMode {
            case .pairwiseDiff:
                return [.rank, .item, .diffStatus, .leftRank, .rightRank, .logRatioDelta]
            case .keywordDatabase:
                return [.rank, .item, .coverageCount, .coverageRate, .meanKeyness, .meanAbsLogRatio, .lastSeenAt]
            }
        }
    }

    func presentation(for key: KeywordColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .item:
            return .keyword
        case .example:
            return .summary
        case .rank, .focusFrequency, .referenceFrequency, .focusRange, .referenceRange, .leftRank, .rightRank, .coverageCount:
            return .numeric(precision: 0)
        case .focusNormFrequency, .referenceNormFrequency, .keyness, .logRatio, .pValue, .logRatioDelta, .coverageRate, .meanKeyness, .meanAbsLogRatio:
            return .numeric(precision: 2)
        case .direction, .diffStatus, .lastSeenAt:
            return .label
        }
    }

    func widthPolicy(for key: KeywordColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .rank, .direction, .diffStatus, .leftRank, .rightRank, .coverageCount:
            return .compact
        case .focusFrequency, .referenceFrequency, .focusNormFrequency, .referenceNormFrequency, .keyness, .logRatio, .pValue, .focusRange, .referenceRange, .logRatioDelta, .coverageRate, .meanKeyness, .meanAbsLogRatio:
            return .numeric
        case .item:
            return .keyword
        case .example, .lastSeenAt:
            return .summary
        }
    }

    func sortIndicator(for key: KeywordColumnKey, sortMode: KeywordSortMode) -> String? {
        switch (key, sortMode) {
        case (.item, .alphabeticalAscending):
            return "↑"
        case (.keyness, .keynessDescending):
            return "↓"
        case (.logRatio, .absLogRatioDescending):
            return "↓"
        case (.focusFrequency, .focusFrequencyDescending):
            return "↓"
        case (.focusNormFrequency, .focusNormFrequencyDescending):
            return "↓"
        case (.focusRange, .focusRangeDescending):
            return "↓"
        case (.coverageCount, .coverageDescending):
            return "↓"
        case (.lastSeenAt, .updatedAtDescending):
            return "↓"
        case (.meanAbsLogRatio, .absLogRatioDescending):
            return "↓"
        case (.meanKeyness, .keynessDescending):
            return "↓"
        case (.logRatioDelta, .absLogRatioDescending):
            return "↓"
        default:
            return nil
        }
    }
}
