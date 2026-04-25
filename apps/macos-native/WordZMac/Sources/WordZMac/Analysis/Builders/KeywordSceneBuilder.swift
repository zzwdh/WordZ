import Foundation

struct KeywordSceneBuilder {
    func build(
        result: KeywordSuiteResult?,
        activeTab: KeywordSuiteTab,
        listMode: KeywordSavedListViewMode,
        primarySavedList: KeywordSavedList?,
        secondarySavedList: KeywordSavedList?,
        savedLists: [KeywordSavedList],
        configuration: KeywordSuiteConfiguration,
        annotationState: WorkspaceAnnotationState = .default,
        focusSelectionSummary: String,
        referenceSelectionSummary: String,
        hasPendingRunChanges: Bool,
        sortMode: KeywordSortMode,
        pageSize: KeywordPageSize,
        currentPage: Int,
        visibleColumns: Set<KeywordColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> KeywordSceneModel {
        let buildRows = buildRows(
            result: result,
            activeTab: activeTab,
            listMode: listMode,
            primarySavedList: primarySavedList,
            secondarySavedList: secondarySavedList,
            savedLists: savedLists
        )
        let sortedRows = sortRows(buildRows.rows, mode: sortMode)
        let pagination = buildPagination(
            totalRows: sortedRows.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = Array(
            sliceRows(
                sortedRows,
                currentPage: pagination.sceneModel.currentPage,
                pageSize: pageSize
            )
        )
        let sceneRows = pageRows.enumerated().map { index, row in
            buildSceneRow(
                row,
                globalRank: pagination.globalStartIndex + index + 1,
                languageMode: languageMode
            )
        }
        let tableRows = sceneRows.map { row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    KeywordColumnKey.rank.rawValue: row.rankText,
                    KeywordColumnKey.item.rawValue: row.item,
                    KeywordColumnKey.direction.rawValue: row.directionText,
                    KeywordColumnKey.focusFrequency.rawValue: row.focusFrequencyText,
                    KeywordColumnKey.referenceFrequency.rawValue: row.referenceFrequencyText,
                    KeywordColumnKey.focusNormFrequency.rawValue: row.focusNormFrequencyText,
                    KeywordColumnKey.referenceNormFrequency.rawValue: row.referenceNormFrequencyText,
                    KeywordColumnKey.keyness.rawValue: row.keynessText,
                    KeywordColumnKey.logRatio.rawValue: row.logRatioText,
                    KeywordColumnKey.pValue.rawValue: row.pValueText,
                    KeywordColumnKey.focusRange.rawValue: row.focusRangeText,
                    KeywordColumnKey.referenceRange.rawValue: row.referenceRangeText,
                    KeywordColumnKey.example.rawValue: row.exampleText,
                    KeywordColumnKey.diffStatus.rawValue: row.diffStatusText,
                    KeywordColumnKey.leftRank.rawValue: row.leftRankText,
                    KeywordColumnKey.rightRank.rawValue: row.rightRankText,
                    KeywordColumnKey.logRatioDelta.rawValue: row.logRatioDeltaText,
                    KeywordColumnKey.coverageCount.rawValue: row.coverageCountText,
                    KeywordColumnKey.coverageRate.rawValue: row.coverageRateText,
                    KeywordColumnKey.meanKeyness.rawValue: row.meanKeynessText,
                    KeywordColumnKey.meanAbsLogRatio.rawValue: row.meanAbsLogRatioText,
                    KeywordColumnKey.lastSeenAt.rawValue: row.lastSeenAtText
                ]
            )
        }

        let focusSummary = buildFocusSummary(
            result: result,
            fallback: focusSelectionSummary,
            languageMode: languageMode
        )
        let referenceSummary = buildReferenceSummary(
            result: result,
            fallback: referenceSelectionSummary,
            languageMode: languageMode
        )
        let configurationSummary = buildConfigurationSummary(
            configuration: configuration,
            languageMode: languageMode
        )
        let annotationSummary = annotationState.summary(in: languageMode)
        let methodSummary = buildMethodSummary(
            activeTab: activeTab,
            listMode: listMode,
            configuration: configuration,
            annotationState: annotationState,
            focusSummary: focusSummary,
            referenceSummary: referenceSummary,
            primarySavedList: primarySavedList,
            secondarySavedList: secondarySavedList,
            hasPendingRunChanges: hasPendingRunChanges,
            languageMode: languageMode
        )
        let methodNotes = buildMethodNotes(
            activeTab: activeTab,
            listMode: listMode,
            configuration: configuration,
            languageMode: languageMode
        )
        let exportMetadataLines = AnalysisExportMetadataSupport.notes(
            analysisTitle: analysisTitle(
                activeTab: activeTab,
                listMode: listMode,
                languageMode: languageMode
            ),
            languageMode: languageMode,
            visibleRows: sceneRows.count,
            totalRows: sortedRows.count,
            stopwordFilter: configuration.tokenFilters.stopwordFilter,
            additionalLines: [
                "\(wordZText("Focus", "Focus", mode: languageMode)): \(focusSummary)",
                "\(wordZText("Reference", "Reference", mode: languageMode)): \(referenceSummary)",
                annotationSummary,
                configurationSummary
            ]
        )

        return KeywordSceneModel(
            activeTab: activeTab,
            listMode: listMode,
            focusSummary: focusSummary,
            referenceSummary: referenceSummary,
            annotationSummary: annotationSummary,
            configurationSummary: configurationSummary,
            methodSummary: methodSummary,
            methodNotes: methodNotes,
            exportMetadataLines: exportMetadataLines,
            sorting: KeywordSortingSceneModel(selectedSort: sortMode, selectedPageSize: pageSize),
            pagination: pagination.sceneModel,
            table: buildTable(
                activeTab: activeTab,
                listMode: listMode,
                statistic: configuration.statistic,
                visibleColumns: visibleColumns,
                sortMode: sortMode,
                languageMode: languageMode
            ),
            totalRows: sortedRows.count,
            visibleRows: sceneRows.count,
            wordsCount: result?.words.count ?? 0,
            termsCount: result?.terms.count ?? 0,
            ngramsCount: result?.ngrams.count ?? 0,
            savedListsCount: savedLists.count,
            rows: sceneRows,
            tableSnapshot: ResultTableSnapshot(rows: tableRows),
            emptyStateTitle: buildRows.emptyTitle,
            emptyStateMessage: buildRows.emptyMessage
        )
    }

    func sortRows(_ rows: [KeywordBuildRow], mode: KeywordSortMode) -> [KeywordBuildRow] {
        rows.sorted { lhs, rhs in
            switch mode {
            case .alphabeticalAscending:
                return compareItems(lhs.item, rhs.item)
            case .updatedAtDescending:
                if lhs.lastSeenAt != rhs.lastSeenAt {
                    return lhs.lastSeenAt > rhs.lastSeenAt
                }
            case .coverageDescending:
                if lhs.coverageCount != rhs.coverageCount {
                    return lhs.coverageCount > rhs.coverageCount
                }
                if lhs.coverageRate != rhs.coverageRate {
                    return lhs.coverageRate > rhs.coverageRate
                }
                if lhs.meanAbsLogRatio != rhs.meanAbsLogRatio {
                    return lhs.meanAbsLogRatio > rhs.meanAbsLogRatio
                }
            case .focusRangeDescending:
                if lhs.focusRange != rhs.focusRange {
                    return lhs.focusRange > rhs.focusRange
                }
            case .focusNormFrequencyDescending:
                if lhs.focusNormFrequency != rhs.focusNormFrequency {
                    return lhs.focusNormFrequency > rhs.focusNormFrequency
                }
            case .focusFrequencyDescending:
                if lhs.focusFrequency != rhs.focusFrequency {
                    return lhs.focusFrequency > rhs.focusFrequency
                }
            case .absLogRatioDescending:
                let lhsValue = lhs.primaryAbsLogRatioSortValue
                let rhsValue = rhs.primaryAbsLogRatioSortValue
                if lhsValue != rhsValue {
                    return lhsValue > rhsValue
                }
            case .keynessDescending:
                let lhsValue = lhs.primaryKeynessSortValue
                let rhsValue = rhs.primaryKeynessSortValue
                if lhsValue != rhsValue {
                    return lhsValue > rhsValue
                }
            }

            if lhs.focusFrequency != rhs.focusFrequency {
                return lhs.focusFrequency > rhs.focusFrequency
            }
            return compareItems(lhs.item, rhs.item)
        }
    }
}
