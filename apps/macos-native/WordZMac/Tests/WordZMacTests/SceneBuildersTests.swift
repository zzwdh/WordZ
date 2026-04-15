import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class SceneBuildersTests: XCTestCase {
    func testStatsSceneBuilderAppliesSortingPaginationAndVisibleColumns() {
        let result = StatsResult(json: [
            "tokenCount": 12,
            "typeCount": 3,
            "ttr": 0.25,
            "sttr": 0.5,
            "sentenceCount": 2,
            "paragraphCount": 1,
            "freqRows": [
                ["word": "gamma", "count": 3, "rank": 3, "normFreq": 2500.0, "range": 1, "normRange": 50.0],
                ["word": "alpha", "count": 10, "rank": 1, "normFreq": 8333.33, "range": 2, "normRange": 100.0],
                ["word": "beta", "count": 7, "rank": 2, "normFreq": 5833.33, "range": 2, "normRange": 100.0]
            ]
        ])

        let scene = StatsSceneBuilder().build(
            from: result,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.rank, .word, .normFrequency, .range]
        )

        XCTAssertEqual(scene.rows.map(\.word), ["alpha", "beta", "gamma"])
        XCTAssertEqual(scene.rows.first?.rankText, "1")
        XCTAssertEqual(scene.rows.first?.normFrequencyText, "8333.33")
        XCTAssertEqual(scene.rows.first?.rangeText, "2")
        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.visibleRows, 3)
        XCTAssertTrue(scene.isColumnVisible(.word))
        XCTAssertTrue(scene.isColumnVisible(.normFrequency))
        XCTAssertFalse(scene.isColumnVisible(.count))
        XCTAssertEqual(scene.columnTitle(for: .word), "词 ↑")
    }

    func testWordSceneBuilderFiltersPureNumericTermsButKeepsAlphanumericTerms() {
        let result = StatsResult(json: [
            "tokenCount": 30,
            "typeCount": 4,
            "ttr": 0.2,
            "sttr": 0.4,
            "sentenceCount": 3,
            "paragraphCount": 2,
            "freqRows": [
                ["word": "2024", "count": 9, "rank": 1, "normFreq": 3000.0, "range": 3, "normRange": 100.0],
                ["word": "alpha", "count": 7, "rank": 2, "normFreq": 2333.33, "range": 2, "normRange": 66.67],
                ["word": "beta2", "count": 5, "rank": 3, "normFreq": 1666.67, "range": 2, "normRange": 66.67],
                ["word": "12345", "count": 4, "rank": 4, "normFreq": 1333.33, "range": 1, "normRange": 33.33]
            ]
        ])

        let scene = WordSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            sortMode: .frequencyDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(WordColumnKey.allCases)
        )

        XCTAssertEqual(scene.rows.map(\.word), ["alpha", "beta2"])
        XCTAssertEqual(scene.totalRows, 2)
        XCTAssertEqual(scene.filteredRows, 2)
        XCTAssertEqual(scene.visibleRows, 2)
    }

    func testFrequencyRowSupportTreatsChineseAndAlphanumericTermsAsLexical() {
        XCTAssertTrue(FrequencyRowSupport.isLexicalWord("词频"))
        XCTAssertTrue(FrequencyRowSupport.isLexicalWord("词2"))
        XCTAssertTrue(FrequencyRowSupport.isLexicalWord("alpha2"))
        XCTAssertFalse(FrequencyRowSupport.isLexicalWord("2024"))
    }

    func testTokenizeSceneBuilderAppliesLanguagePresetAndLemmaStrategy() {
        let result = TokenizeResult(
            sentences: [
                TokenizedSentence(
                    sentenceId: 0,
                    text: "Running 跑步 2024",
                    tokens: [
                        TokenizedToken(
                            original: "Running",
                            normalized: "running",
                            sentenceId: 0,
                            tokenIndex: 0,
                            annotations: TokenLinguisticAnnotations(script: .latin, lemma: "run", lexicalClass: .verb)
                        ),
                        TokenizedToken(
                            original: "跑步",
                            normalized: "跑步",
                            sentenceId: 0,
                            tokenIndex: 1,
                            annotations: TokenLinguisticAnnotations(script: .cjk, lemma: nil, lexicalClass: .verb)
                        ),
                        TokenizedToken(
                            original: "2024",
                            normalized: "2024",
                            sentenceId: 0,
                            tokenIndex: 2,
                            annotations: TokenLinguisticAnnotations(script: .numeric, lemma: nil, lexicalClass: .number)
                        )
                    ]
                )
            ]
        )

        let scene = TokenizeSceneBuilder().build(
            from: result,
            query: "run",
            searchOptions: .default,
            stopwordFilter: .default,
            languagePreset: .latinFocused,
            lemmaStrategy: .lemmaPreferred,
            sortMode: .lemmaAscending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(TokenizeColumnKey.allCases)
        )

        XCTAssertEqual(scene.filteredTokens, 1)
        XCTAssertEqual(scene.visibleTokens, 1)
        XCTAssertEqual(scene.rows.first?.lemma, "run")
        XCTAssertEqual(scene.rows.first?.lexicalClass, TokenLexicalClass.verb.title(in: .system))
        XCTAssertEqual(scene.rows.first?.script, TokenScript.latin.title(in: .system))
        XCTAssertEqual(scene.exportDocument?.text, "run\n")
        XCTAssertEqual(scene.sorting.selectedLanguagePreset, .latinFocused)
        XCTAssertEqual(scene.sorting.selectedLemmaStrategy, .lemmaPreferred)
        XCTAssertTrue(scene.column(for: .lemma)?.isVisible ?? false)
    }

    func testKWICSceneBuilderRespectsSortingAndPaging() {
        let result = KWICResult(json: [
            "rows": [
                ["sentenceId": 2, "sentenceTokenIndex": 0, "left": "z", "node": "beta", "right": "r2"],
                ["sentenceId": 0, "sentenceTokenIndex": 0, "left": "a", "node": "alpha", "right": "r0"],
                ["sentenceId": 1, "sentenceTokenIndex": 0, "left": "m", "node": "gamma", "right": "r1"]
            ]
        ])

        let scene = KWICSceneBuilder().build(
            from: result,
            query: "alpha",
            searchOptions: .default,
            stopwordFilter: .default,
            leftWindow: 5,
            rightWindow: 5,
            sortMode: .sentenceAscending,
            pageSize: .twentyFive,
            currentPage: 1,
            visibleColumns: [.keyword, .sentenceIndex]
        )

        XCTAssertEqual(scene.rows.map(\.sentenceIndexText), ["1", "2", "3"])
        XCTAssertEqual(scene.filteredRows, 3)
        XCTAssertFalse(scene.isColumnVisible(.leftContext))
        XCTAssertTrue(scene.isColumnVisible(.keyword))
        XCTAssertEqual(scene.columnTitle(for: .sentenceIndex), "句号 ↑")
        XCTAssertEqual(scene.rows.first?.concordanceText, "a [alpha] r0")
        XCTAssertTrue(scene.rows.first?.citationText.contains("Sentence 1") ?? false)
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("节点词") || $0.contains("Keyword") }))
    }

    func testCollocateSceneBuilderBuildsRankAndColumnIndicators() {
        let result = CollocateResult(items: [
            [
                "word": "beta",
                "total": 4,
                "left": 1,
                "right": 3,
                "wordFreq": 9,
                "keywordFreq": 12,
                "rate": 0.4,
                "logDice": 8.1,
                "mutualInformation": 2.1,
                "tScore": 3.2
            ],
            [
                "word": "alpha",
                "total": 8,
                "left": 5,
                "right": 3,
                "wordFreq": 11,
                "keywordFreq": 12,
                "rate": 0.7,
                "logDice": 10.2,
                "mutualInformation": 1.8,
                "tScore": 4.7
            ]
        ])

        let scene = CollocateSceneBuilder().build(
            from: result,
            query: "node",
            searchOptions: .default,
            stopwordFilter: .default,
            focusMetric: .logDice,
            leftWindow: 4,
            rightWindow: 6,
            minFreq: 2,
            sortMode: .logDiceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.rank, .word, .total, .logDice, .rate]
        )

        XCTAssertEqual(scene.rows.map(\.rankText), ["1", "2"])
        XCTAssertEqual(scene.rows.map(\.word), ["alpha", "beta"])
        XCTAssertEqual(scene.filteredRows, 2)
        XCTAssertEqual(scene.columnTitle(for: .logDice), "LogDice ↓")
        XCTAssertEqual(scene.focusMetric, .logDice)
        XCTAssertTrue(scene.methodSummary.contains("L4 / R6"))
        XCTAssertTrue(scene.isColumnVisible(.rate))
        XCTAssertFalse(scene.isColumnVisible(.left))
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("最小频次") || $0.contains("Minimum Frequency") }))
    }

    func testCompareSceneBuilderBuildsSelectionSummariesAndSortedRows() {
        let scene = CompareSceneBuilder().build(
            selection: [
                CompareSelectableCorpusSceneItem(id: "corpus-1", title: "A", subtitle: "Default", isSelected: true),
                CompareSelectableCorpusSceneItem(id: "corpus-2", title: "B", subtitle: "Default", isSelected: true)
            ],
            from: makeCompareResult(),
            query: "a",
            searchOptions: SearchOptionsState(words: false, caseSensitive: false, regex: false),
            stopwordFilter: .default,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.word, .total, .distribution]
        )

        XCTAssertEqual(scene.corpusSummaries.count, 2)
        XCTAssertEqual(scene.rows.first?.word, "alpha")
        XCTAssertEqual(scene.rows.first?.keynessText, "4.21")
        XCTAssertEqual(scene.filteredRows, 2)
        XCTAssertEqual(scene.columnTitle(for: CompareColumnKey.word), "词 ↑")
        XCTAssertTrue(scene.columnTitle(for: CompareColumnKey.keyness).contains("Keyness"))
        XCTAssertFalse(scene.isColumnVisible(CompareColumnKey.range))
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("Selected Corpora") || $0.contains("所选语料") }))
    }

    func testCompareSceneBuilderRecomputesAndResortsForFixedReferenceCorpus() {
        let scene = CompareSceneBuilder().build(
            selection: [
                CompareSelectableCorpusSceneItem(id: "corpus-1", title: "Demo Corpus", subtitle: "Default", isSelected: true),
                CompareSelectableCorpusSceneItem(id: "corpus-2", title: "Compare Corpus", subtitle: "Default", isSelected: true)
            ],
            from: makeCompareResult(),
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            referenceCorpusID: "corpus-1",
            sortMode: .keynessDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.word, .keyness, .effect]
        )

        XCTAssertEqual(scene.rows.first?.word, "beta")
        XCTAssertEqual(scene.rows.first?.referenceLabelText, "Demo Corpus")
        XCTAssertTrue(scene.referenceSummary.contains("Demo Corpus"))
        XCTAssertTrue(scene.methodSummary.contains("固定参考语料") || scene.methodSummary.contains("fixed reference corpus"))
    }

    func testKeywordSceneBuilderBuildsPairwiseDiffRowsForSavedLists() {
        let configuration = makeKeywordSuiteResult().configuration
        let left = KeywordSavedList(
            id: "left",
            name: "Left",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-11T00:00:00Z",
            focusLabel: "Focus A",
            referenceLabel: "Reference A",
            configuration: configuration,
            rows: [
                KeywordSuiteRow(
                    group: .words,
                    item: "alpha",
                    direction: .positive,
                    focusFrequency: 10,
                    referenceFrequency: 2,
                    focusNormalizedFrequency: 10_000,
                    referenceNormalizedFrequency: 2_000,
                    keynessScore: 9.0,
                    logRatio: 2.5,
                    pValue: 0.001,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "alpha left",
                    focusExampleCorpusID: "corpus-1",
                    referenceExampleCorpusID: "corpus-2"
                ),
                KeywordSuiteRow(
                    group: .words,
                    item: "gamma",
                    direction: .positive,
                    focusFrequency: 7,
                    referenceFrequency: 1,
                    focusNormalizedFrequency: 7_000,
                    referenceNormalizedFrequency: 1_000,
                    keynessScore: 7.0,
                    logRatio: 1.8,
                    pValue: 0.01,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "gamma left",
                    focusExampleCorpusID: "corpus-1",
                    referenceExampleCorpusID: "corpus-2"
                )
            ]
        )
        let right = KeywordSavedList(
            id: "right",
            name: "Right",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-12T00:00:00Z",
            focusLabel: "Focus B",
            referenceLabel: "Reference B",
            configuration: configuration,
            rows: [
                KeywordSuiteRow(
                    group: .words,
                    item: "alpha",
                    direction: .positive,
                    focusFrequency: 8,
                    referenceFrequency: 3,
                    focusNormalizedFrequency: 8_000,
                    referenceNormalizedFrequency: 3_000,
                    keynessScore: 6.0,
                    logRatio: 1.0,
                    pValue: 0.02,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "alpha right",
                    focusExampleCorpusID: "corpus-3",
                    referenceExampleCorpusID: "corpus-4"
                ),
                KeywordSuiteRow(
                    group: .words,
                    item: "beta",
                    direction: .positive,
                    focusFrequency: 5,
                    referenceFrequency: 1,
                    focusNormalizedFrequency: 5_000,
                    referenceNormalizedFrequency: 1_000,
                    keynessScore: 5.0,
                    logRatio: 0.7,
                    pValue: 0.04,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "beta right",
                    focusExampleCorpusID: "corpus-3",
                    referenceExampleCorpusID: "corpus-4"
                )
            ]
        )

        let scene = KeywordSceneBuilder().build(
            result: nil,
            activeTab: .lists,
            listMode: .pairwiseDiff,
            primarySavedList: left,
            secondarySavedList: right,
            savedLists: [left, right],
            configuration: configuration,
            focusSelectionSummary: "Focus",
            referenceSelectionSummary: "Reference",
            hasPendingRunChanges: false,
            sortMode: .alphabeticalAscending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(KeywordColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.rows.map(\.item), ["alpha", "beta", "gamma"])
        XCTAssertTrue(
            scene.rows.first?.diffStatusText == "共有"
                || scene.rows.first?.diffStatusText == "Shared"
        )
        XCTAssertEqual(scene.rows.first?.leftRankText, "1")
        XCTAssertEqual(scene.rows.first?.rightRankText, "1")
        XCTAssertEqual(scene.rows.first?.logRatioDeltaText, "1.50")
        XCTAssertTrue(scene.methodSummary.contains("Left"))
        XCTAssertTrue(scene.methodSummary.contains("Right"))
    }

    func testKeywordSceneBuilderBuildsKeywordDatabaseCoverageRows() {
        let configuration = makeKeywordSuiteResult().configuration
        let listA = KeywordSavedList(
            id: "a",
            name: "List A",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-11T00:00:00Z",
            focusLabel: "Focus A",
            referenceLabel: "Reference A",
            configuration: configuration,
            rows: [
                KeywordSuiteRow(
                    group: .words,
                    item: "alpha",
                    direction: .positive,
                    focusFrequency: 12,
                    referenceFrequency: 2,
                    focusNormalizedFrequency: 12_000,
                    referenceNormalizedFrequency: 2_000,
                    keynessScore: 10,
                    logRatio: 2.0,
                    pValue: 0.001,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "alpha",
                    focusExampleCorpusID: "corpus-1",
                    referenceExampleCorpusID: "corpus-2"
                ),
                KeywordSuiteRow(
                    group: .words,
                    item: "gamma",
                    direction: .positive,
                    focusFrequency: 9,
                    referenceFrequency: 1,
                    focusNormalizedFrequency: 9_000,
                    referenceNormalizedFrequency: 1_000,
                    keynessScore: 9,
                    logRatio: 1.5,
                    pValue: 0.01,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "gamma",
                    focusExampleCorpusID: "corpus-1",
                    referenceExampleCorpusID: "corpus-2"
                )
            ]
        )
        let listB = KeywordSavedList(
            id: "b",
            name: "List B",
            group: .words,
            createdAt: "2026-04-12T00:00:00Z",
            updatedAt: "2026-04-12T00:00:00Z",
            focusLabel: "Focus B",
            referenceLabel: "Reference B",
            configuration: configuration,
            rows: [
                KeywordSuiteRow(
                    group: .words,
                    item: "alpha",
                    direction: .negative,
                    focusFrequency: 7,
                    referenceFrequency: 14,
                    focusNormalizedFrequency: 7_000,
                    referenceNormalizedFrequency: 14_000,
                    keynessScore: 8,
                    logRatio: -1.2,
                    pValue: 0.02,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "alpha",
                    focusExampleCorpusID: "corpus-3",
                    referenceExampleCorpusID: "corpus-4"
                ),
                KeywordSuiteRow(
                    group: .words,
                    item: "beta",
                    direction: .positive,
                    focusFrequency: 6,
                    referenceFrequency: 1,
                    focusNormalizedFrequency: 6_000,
                    referenceNormalizedFrequency: 1_000,
                    keynessScore: 6,
                    logRatio: 0.9,
                    pValue: 0.03,
                    focusRange: 1,
                    referenceRange: 1,
                    example: "beta",
                    focusExampleCorpusID: "corpus-3",
                    referenceExampleCorpusID: "corpus-4"
                )
            ]
        )

        let scene = KeywordSceneBuilder().build(
            result: nil,
            activeTab: .lists,
            listMode: .keywordDatabase,
            primarySavedList: nil,
            secondarySavedList: nil,
            savedLists: [listA, listB],
            configuration: configuration,
            focusSelectionSummary: "Focus",
            referenceSelectionSummary: "Reference",
            hasPendingRunChanges: false,
            sortMode: .coverageDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(KeywordColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.rows.first?.item, "alpha")
        XCTAssertEqual(scene.rows.first?.coverageCountText, "2")
        XCTAssertEqual(scene.rows.first?.coverageRateText, "1.00")
        XCTAssertEqual(scene.rows.first?.meanKeynessText, "9.00")
        XCTAssertEqual(scene.rows.first?.meanAbsLogRatioText, "1.60")
        XCTAssertEqual(scene.rows.first?.lastSeenAtText, "2026-04-12T00:00:00Z")
    }

    func testKeywordSceneBuilderBuildsListSpecificTableDescriptors() {
        let builder = KeywordSceneBuilder()

        let pairwiseTable = builder.buildTable(
            activeTab: .lists,
            listMode: .pairwiseDiff,
            statistic: .logLikelihood,
            visibleColumns: Set(KeywordColumnKey.allCases),
            sortMode: .absLogRatioDescending,
            languageMode: .system
        )
        XCTAssertEqual(pairwiseTable.storageKey, "keyword-lists-pairwiseDiff")
        XCTAssertEqual(
            pairwiseTable.columns.map(\.id),
            [
                KeywordColumnKey.rank.rawValue,
                KeywordColumnKey.item.rawValue,
                KeywordColumnKey.diffStatus.rawValue,
                KeywordColumnKey.leftRank.rawValue,
                KeywordColumnKey.rightRank.rawValue,
                KeywordColumnKey.logRatioDelta.rawValue
            ]
        )
        XCTAssertEqual(pairwiseTable.defaultDensity, .standard)
        XCTAssertEqual(pairwiseTable.column(id: KeywordColumnKey.logRatioDelta.rawValue)?.sortIndicator, "↓")

        let keywordTable = builder.buildTable(
            activeTab: .words,
            listMode: .pairwiseDiff,
            statistic: .chiSquare,
            visibleColumns: Set(KeywordColumnKey.allCases),
            sortMode: .keynessDescending,
            languageMode: .system
        )
        XCTAssertEqual(keywordTable.storageKey, "keyword-words-pairwiseDiff")
        XCTAssertEqual(keywordTable.defaultDensity, .reading)
        XCTAssertEqual(keywordTable.columns.first?.id, KeywordColumnKey.rank.rawValue)
        XCTAssertEqual(keywordTable.columns.last?.id, KeywordColumnKey.example.rawValue)
        XCTAssertEqual(keywordTable.column(id: KeywordColumnKey.keyness.rawValue)?.sortIndicator, "↓")
    }

    func testKeywordSceneBuilderPaginationClampsRequestedPage() {
        let pagination = KeywordSceneBuilder().buildPagination(
            totalRows: 51,
            currentPage: 9,
            pageSize: .twentyFive,
            languageMode: .system
        )

        XCTAssertEqual(pagination.globalStartIndex, 50)
        XCTAssertEqual(pagination.sceneModel.currentPage, 3)
        XCTAssertEqual(pagination.sceneModel.totalPages, 3)
        XCTAssertEqual(pagination.sceneModel.rangeLabel, "51-51 / 51")
        XCTAssertTrue(pagination.sceneModel.canGoBackward)
        XCTAssertFalse(pagination.sceneModel.canGoForward)
    }

    func testChiSquareSceneBuilderBuildsMetricsAndWarnings() {
        let scene = ChiSquareSceneBuilder().build(from: makeChiSquareResult())

        XCTAssertEqual(scene.metrics.count, 6)
        XCTAssertEqual(scene.observedRows.count, 2)
        XCTAssertEqual(scene.summary, "差异不显著")
        XCTAssertEqual(scene.methodLabel, "Pearson χ²")
        XCTAssertEqual(scene.rowTotals.count, 2)
        XCTAssertEqual(scene.columnTotals.count, 3)
        XCTAssertFalse(scene.tableRows.isEmpty)
        XCTAssertEqual(scene.table.csvHeaderRow(), ["section", "label", "value", "value2"])
    }

    func testLocatorSceneBuilderBuildsPaginationAndVisibleColumns() {
        let scene = LocatorSceneBuilder().build(
            from: makeLocatorResult(rowCount: 30),
            source: LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 1),
            leftWindow: 4,
            rightWindow: 6,
            pageSize: .twentyFive,
            currentPage: 1,
            visibleColumns: [.sentenceId, .status, .text]
        )

        XCTAssertEqual(scene.rows.count, 25)
        XCTAssertEqual(scene.totalRows, 30)
        XCTAssertEqual(scene.pagination.rangeLabel, "1-25 / 30")
        XCTAssertFalse(scene.isColumnVisible(.leftWords))
        XCTAssertTrue(scene.isColumnVisible(.text))
        XCTAssertTrue(scene.rows[1].concordanceText.contains("[node]"))
        XCTAssertTrue(scene.rows[1].citationText.contains("Full: sentence-1"))
    }

    func testConcordancePresentationSupportNormalizesWhitespaceConsistently() {
        XCTAssertEqual(
            ConcordancePresentationSupport.normalizedContext("  alpha \n beta\tgamma  "),
            "alpha beta gamma"
        )
        XCTAssertEqual(
            ConcordancePresentationSupport.annotatedLine(
                normalizedLeft: "left side",
                normalizedKeyword: "node",
                normalizedRight: "right side"
            ),
            "left side [node] right side"
        )
        XCTAssertEqual(
            ConcordancePresentationSupport.citationText(
                sentenceNumber: 2,
                normalizedKeyword: "node",
                normalizedLeft: "left side",
                normalizedRight: "right side",
                normalizedFullText: "full sentence"
            ),
            "Sentence 2\nleft side [node] right side\nFull: full sentence"
        )
    }

    func testNgramSceneBuilderRespectsFilterSortingAndPaging() {
        let result = NgramResult(json: [
            "n": 3,
            "rows": [
                ["zeta beta", 2],
                ["alpha beta", 10],
                ["beta gamma", 7]
            ]
        ])

        let scene = NgramSceneBuilder().build(
            from: result,
            query: "beta",
            searchOptions: SearchOptionsState(words: false, caseSensitive: false, regex: false),
            stopwordFilter: .default,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.phrase, .count]
        )

        XCTAssertEqual(scene.n, 3)
        XCTAssertEqual(scene.rows.map(\NgramSceneRow.phrase), ["alpha beta", "beta gamma", "zeta beta"])
        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.filteredRows, 3)
        XCTAssertEqual(scene.visibleRows, 3)
        XCTAssertFalse(scene.isColumnVisible(NgramColumnKey.rank))
        XCTAssertEqual(scene.columnTitle(for: NgramColumnKey.phrase), "N-Gram ↑")
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("N-Gram 阶数") || $0.contains("N-Gram Size") }))
    }

    func testReadingExportSupportBuildsKWICAndLocatorDocuments() {
        let kwicScene = KWICSceneBuilder().build(
            from: makeKWICResult(rowCount: 3),
            query: "node",
            searchOptions: .default,
            stopwordFilter: .default,
            leftWindow: 5,
            rightWindow: 5,
            sortMode: .original,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(KWICColumnKey.allCases)
        )
        let kwicDocument = ReadingExportSupport.document(
            for: .citation,
            currentKWICRow: kwicScene.rows[0],
            scene: kwicScene
        )

        XCTAssertEqual(kwicDocument.suggestedName, "kwic-citation.txt")
        XCTAssertTrue(kwicDocument.text.contains(kwicScene.rows[0].citationText))
        XCTAssertTrue(kwicDocument.text.contains("Keyword") || kwicDocument.text.contains("节点词"))

        let locatorScene = LocatorSceneBuilder().build(
            from: makeLocatorResult(rowCount: 4),
            source: LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 1),
            leftWindow: 4,
            rightWindow: 6,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(LocatorColumnKey.allCases)
        )
        let locatorDocument = ReadingExportSupport.document(
            for: .fullSentence,
            visibleLocatorRows: Array(locatorScene.rows.prefix(2)),
            scene: locatorScene
        )

        XCTAssertEqual(locatorDocument.suggestedName, "locator-visible-fullSentence.txt")
        XCTAssertTrue(locatorDocument.text.contains("sentence-0"))
        XCTAssertTrue(locatorDocument.text.contains("sentence-1"))
        XCTAssertTrue(locatorDocument.text.contains("Window: L4 / R6"))
    }

    func testReadingExportSupportBuildsCompareAndCollocateSummaryDocuments() {
        let compareScene = CompareSceneBuilder().build(
            selection: [
                CompareSelectableCorpusSceneItem(id: "corpus-1", title: "Demo Corpus", subtitle: "Default", isSelected: true),
                CompareSelectableCorpusSceneItem(id: "corpus-2", title: "Compare Corpus", subtitle: "Default", isSelected: true)
            ],
            from: makeCompareResult(),
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            sortMode: .keynessDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(CompareColumnKey.allCases)
        )
        let compareDocument = ReadingExportSupport.document(
            currentCompareRow: compareScene.rows[0],
            scene: compareScene
        )

        XCTAssertEqual(compareDocument.suggestedName, "compare-summary.txt")
        XCTAssertTrue(compareDocument.text.contains(compareScene.rows[0].word))
        XCTAssertTrue(compareDocument.text.contains("Keyness:"))
        XCTAssertTrue(compareDocument.text.contains(compareScene.referenceSummary))
        XCTAssertTrue(compareDocument.text.contains(compareScene.methodSummary))

        let collocateScene = CollocateSceneBuilder().build(
            from: makeCollocateResult(rowCount: 3),
            query: "node",
            searchOptions: .default,
            stopwordFilter: .default,
            focusMetric: .logDice,
            leftWindow: 4,
            rightWindow: 6,
            minFreq: 2,
            sortMode: .logDiceDescending,
            pageSize: .all,
            currentPage: 1,
            visibleColumns: Set(CollocateColumnKey.allCases)
        )
        let collocateDocument = ReadingExportSupport.document(
            visibleCollocateRows: Array(collocateScene.rows.prefix(2)),
            scene: collocateScene
        )

        XCTAssertEqual(collocateDocument.suggestedName, "collocate-visible-summary.txt")
        XCTAssertTrue(collocateDocument.text.contains(collocateScene.rows[0].word))
        XCTAssertTrue(collocateDocument.text.contains("Focus Metric:"))
        XCTAssertTrue(collocateDocument.text.contains(collocateScene.focusMetricSummary))
        XCTAssertTrue(collocateDocument.text.contains(collocateScene.methodSummary))

        let compareMethodDocument = ReadingExportSupport.compareMethodDocument(scene: compareScene)
        XCTAssertEqual(compareMethodDocument.suggestedName, "compare-method-summary.txt")
        XCTAssertTrue(compareMethodDocument.text.contains(compareScene.methodSummary))
        XCTAssertTrue(compareMethodDocument.text.contains(compareScene.referenceSummary))

        let collocateMethodDocument = ReadingExportSupport.collocateMethodDocument(scene: collocateScene)
        XCTAssertEqual(collocateMethodDocument.suggestedName, "collocate-method-summary.txt")
        XCTAssertTrue(collocateMethodDocument.text.contains(collocateScene.methodSummary))
        XCTAssertTrue(collocateMethodDocument.text.contains(collocateScene.methodNotes[0]))
    }
}
