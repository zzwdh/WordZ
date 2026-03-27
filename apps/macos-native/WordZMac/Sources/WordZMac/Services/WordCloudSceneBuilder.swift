import Foundation

struct WordCloudSceneBuilder {
    func build(
        from result: WordCloudResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        limit: Int,
        visibleColumns: Set<WordCloudColumnKey>
    ) -> WordCloudSceneModel {
        let filtered = SearchFilterSupport.filterWordLikeRows(
            result.rows,
            query: query,
            options: searchOptions,
            stopword: stopwordFilter
        ) { $0.word }
        let limitedRows = Array(filtered.rows.prefix(max(1, limit)))
        let maxCount = limitedRows.first?.count ?? 1
        let minCount = limitedRows.last?.count ?? 0
        let countRange = max(maxCount - minCount, 1)

        let cloudItems = limitedRows.enumerated().map { index, row in
            let prominence = (Double(row.count - minCount) / Double(countRange))
            return WordCloudTermSceneItem(
                id: row.id,
                word: row.word,
                countText: "\(row.count)",
                prominenceText: String(format: "%.2f", prominence),
                fontScale: 0.85 + (prominence * 1.25),
                isAccent: index < 12
            )
        }

        let columns = WordCloudColumnKey.allCases.map { key in
            NativeTableColumnDescriptor(
                id: key.rawValue,
                title: key.title,
                isVisible: visibleColumns.contains(key),
                sortIndicator: nil
            )
        }

        let tableRows = cloudItems.map { item in
            NativeTableRowDescriptor(
                id: item.id,
                values: [
                    WordCloudColumnKey.word.rawValue: item.word,
                    WordCloudColumnKey.count.rawValue: item.countText,
                    WordCloudColumnKey.prominence.rawValue: item.prominenceText
                ]
            )
        }

        return WordCloudSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            limit: limit,
            totalRows: result.rows.count,
            visibleRows: tableRows.count,
            table: NativeTableDescriptor(storageKey: "wordcloud", columns: columns),
            tableRows: tableRows,
            cloudItems: cloudItems,
            searchError: filtered.error
        )
    }
}
