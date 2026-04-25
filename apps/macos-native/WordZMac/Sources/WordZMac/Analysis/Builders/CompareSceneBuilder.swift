import Foundation

struct CompareSceneBuilder {
    func build(
        selection: [CompareSelectableCorpusSceneItem],
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        annotationState: WorkspaceAnnotationState = .default,
        sentimentSummary: CompareSentimentSummary? = nil,
        sentimentExplainer: CompareSentimentExplainer? = nil,
        referenceCorpusID: String?,
        sortMode: CompareSortMode,
        pageSize: ComparePageSize,
        currentPage: Int,
        visibleColumns: Set<CompareColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> CompareSceneModel {
        build(
            selection: selection,
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationState: annotationState,
            sentimentSummary: sentimentSummary,
            sentimentExplainer: sentimentExplainer,
            referenceSelection: referenceCorpusID.map(CompareReferenceSelection.corpus) ?? .automatic,
            referenceCorpusSets: [],
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode
        )
    }

    func build(
        selection: [CompareSelectableCorpusSceneItem],
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        annotationState: WorkspaceAnnotationState = .default,
        sentimentSummary: CompareSentimentSummary? = nil,
        sentimentExplainer: CompareSentimentExplainer? = nil,
        referenceSelection: CompareReferenceSelection = .automatic,
        referenceCorpusSets: [LibraryCorpusSetItem] = [],
        sortMode: CompareSortMode,
        pageSize: ComparePageSize,
        currentPage: Int,
        visibleColumns: Set<CompareColumnKey>,
        languageMode: AppLanguageMode = .system
    ) -> CompareSceneModel {
        let filtered = filterRows(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter
        )
        let derivedRows = buildDerivedRows(
            from: filtered.rows,
            referenceSelection: referenceSelection,
            referenceCorpusSets: referenceCorpusSets,
            languageMode: languageMode
        )
        let sortedRows = sortRows(derivedRows, mode: sortMode)
        return build(
            selection: selection,
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationState: annotationState,
            sentimentSummary: sentimentSummary,
            sentimentExplainer: sentimentExplainer,
            referenceSelection: referenceSelection,
            referenceCorpusSets: referenceCorpusSets,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode,
            filteredRows: filtered.rows,
            derivedRows: derivedRows,
            sortedRows: sortedRows,
            searchError: filtered.error
        )
    }

    func build(
        selection: [CompareSelectableCorpusSceneItem],
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        annotationState: WorkspaceAnnotationState = .default,
        sentimentSummary: CompareSentimentSummary? = nil,
        sentimentExplainer: CompareSentimentExplainer? = nil,
        referenceSelection: CompareReferenceSelection = .automatic,
        referenceCorpusSets: [LibraryCorpusSetItem] = [],
        sortMode: CompareSortMode,
        pageSize: ComparePageSize,
        currentPage: Int,
        visibleColumns: Set<CompareColumnKey>,
        languageMode: AppLanguageMode = .system,
        filteredRows: [CompareRow],
        derivedRows: [DerivedCompareRow],
        sortedRows: [DerivedCompareRow],
        searchError: String
    ) -> CompareSceneModel {
        let pagination = buildPagination(
            totalRows: sortedRows.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageRows = sliceRows(sortedRows, currentPage: pagination.currentPage, pageSize: pageSize)

        let sceneRows = buildSceneRows(from: Array(pageRows))
        let tableRows = buildTableRows(from: sceneRows)
        let summaries = buildCorpusSummaries(from: result.corpora, languageMode: languageMode)
        let methodDetails = buildMethodDetails(
            selection: selection,
            referenceSelection: referenceSelection,
            referenceCorpusSets: referenceCorpusSets,
            languageMode: languageMode
        )
        let annotationSummary = annotationState.summary(in: languageMode)
        let exportMetadataLines = buildExportMetadata(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationSummary: annotationSummary,
            sentimentSummary: sentimentSummary,
            sentimentExplainer: sentimentExplainer,
            referenceSummary: methodDetails.referenceSummary,
            selectedTitles: methodDetails.selectedTitles,
            visibleRows: sceneRows.count,
            totalRows: sortedRows.count,
            languageMode: languageMode
        )

        return CompareSceneModel(
            selection: selection,
            corpusSummaries: summaries,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationSummary: annotationSummary,
            referenceSummary: methodDetails.referenceSummary,
            methodSummary: methodDetails.methodSummary,
            methodNotes: methodDetails.methodNotes,
            sentimentSummary: sentimentSummary,
            sentimentExplainer: sentimentExplainer,
            exportMetadataLines: exportMetadataLines,
            sorting: CompareSortingSceneModel(
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            pagination: pagination,
            table: NativeTableDescriptor(
                storageKey: "compare",
                columns: CompareColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .word || key == .keyness
                    )
                },
                defaultDensity: .standard
            ),
            totalRows: result.rows.count,
            filteredRows: filteredRows.count,
            visibleRows: sceneRows.count,
            rows: sceneRows,
            tableSnapshot: ResultTableSnapshot(rows: tableRows),
            searchError: searchError
        )
    }

    func filterRows(
        from result: CompareResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState
    ) -> (rows: [CompareRow], error: String) {
        SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
    }
}
