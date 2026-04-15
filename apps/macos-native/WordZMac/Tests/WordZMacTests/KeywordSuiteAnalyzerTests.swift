import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class KeywordSuiteAnalyzerTests: XCTestCase {
    func testKeywordSuiteAnalyzerSupportsPositiveNegativeAndBothDirections() {
        let positive = KeywordSuiteAnalyzer.analyze(
            makeRequest(direction: .positive)
        )
        XCTAssertEqual(positive.words.map(\.item), ["apple"])
        XCTAssertEqual(positive.words.map(\.direction), [.positive])

        let negative = KeywordSuiteAnalyzer.analyze(
            makeRequest(direction: .negative)
        )
        XCTAssertEqual(negative.words.map(\.item), ["banana"])
        XCTAssertEqual(negative.words.map(\.direction), [.negative])

        let both = KeywordSuiteAnalyzer.analyze(
            makeRequest(direction: .both)
        )
        XCTAssertEqual(Set(both.words.map(\.item)), Set(["apple", "banana"]))
        XCTAssertEqual(Set(both.words.map(\.direction)), Set([.positive, .negative]))
    }

    func testImportedReferenceParserRejectsBlankAndInvalidLinesAndReportsSummary() {
        let parseResult = KeywordSuiteAnalyzer.parseImportedReference(
            "apple\t2\n\nbanana\t0\npear\tnope\norange\napple\t3\n"
        )

        XCTAssertEqual(parseResult.totalLineCount, 6)
        XCTAssertEqual(parseResult.acceptedLineCount, 3)
        XCTAssertEqual(parseResult.rejectedLineCount, 3)
        XCTAssertEqual(
            parseResult.items,
            [
                KeywordReferenceWordListItem(term: "apple", frequency: 5),
                KeywordReferenceWordListItem(term: "orange", frequency: 1)
            ]
        )
    }

    func testKeywordSuiteAnalyzerRoutesImportedWordListItemsToCorrectResultGroups() {
        var configuration = makeConfiguration(direction: .both)
        configuration.referenceSource = KeywordReferenceSource(
            kind: .importedWordList,
            importedListText: "apple\t4\nlanguage model\t5"
        )

        let result = KeywordSuiteAnalyzer.analyze(
            KeywordSuiteRunRequest(
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: "focus",
                        corpusName: "Focus",
                        folderName: "Default",
                        content: "apple apple language model language model"
                    )
                ],
                referenceEntries: [],
                importedReferenceItems: KeywordSuiteAnalyzer.parseImportedReferenceItems("apple\t4\nlanguage model\t5"),
                focusLabel: "Focus",
                referenceLabel: "Imported",
                configuration: configuration
            )
        )

        XCTAssertTrue(result.referenceSummary.isWordList)
        XCTAssertTrue(result.words.contains(where: { $0.item == "apple" && $0.direction == .negative }))
        XCTAssertFalse(result.words.contains(where: { $0.item == "language model" }))
        XCTAssertTrue(result.terms.contains(where: { $0.item == "language model" && $0.direction == .negative }))
        XCTAssertTrue(result.ngrams.contains(where: { $0.item == "language model" && $0.direction == .negative }))
    }

    func testKeywordSuiteAnalyzerSupportsImportedReferenceWordList() {
        var configuration = makeConfiguration(direction: .both)
        configuration.referenceSource = KeywordReferenceSource(
            kind: .importedWordList,
            importedListText: "banana\t5\norange\t1"
        )

        let result = KeywordSuiteAnalyzer.analyze(
            KeywordSuiteRunRequest(
                focusEntries: [makeFocusEntry()],
                referenceEntries: [],
                importedReferenceItems: KeywordSuiteAnalyzer.parseImportedReferenceItems("banana\t5\norange\t1"),
                focusLabel: "Focus",
                referenceLabel: "Imported",
                configuration: configuration
            )
        )

        XCTAssertTrue(result.referenceSummary.isWordList)
        XCTAssertEqual(result.referenceSummary.tokenCount, 6)
        XCTAssertTrue(result.words.contains(where: { $0.item == "banana" && $0.direction == .negative }))
    }

    func testKeywordSuiteAnalyzerGeneratesNgramsAndTerms() {
        let focus = KeywordRequestEntry(
            corpusId: "focus",
            corpusName: "Focus",
            folderName: "Default",
            content: "language model language model language model"
        )
        let reference = KeywordRequestEntry(
            corpusId: "reference",
            corpusName: "Reference",
            folderName: "Default",
            content: "model model model"
        )

        let result = KeywordSuiteAnalyzer.analyze(
            makeRequest(
                direction: .positive,
                focusEntries: [focus],
                referenceEntries: [reference]
            )
        )

        XCTAssertTrue(result.ngrams.contains(where: { $0.item == "language model" }))
        XCTAssertTrue(Set(result.terms.map(\.item)).isSubset(of: Set(result.ngrams.map(\.item))))
    }

    func testKeywordSuiteAnalyzerSupportsLemmaPreferredUnit() {
        let result = KeywordSuiteAnalyzer.analyze(
            makeRequest(
                direction: .positive,
                unit: .lemmaPreferred,
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: "focus",
                        corpusName: "Focus",
                        folderName: "Default",
                        content: "running runs running runner"
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: "reference",
                        corpusName: "Reference",
                        folderName: "Default",
                        content: "run runner runner runner"
                    )
                ]
            )
        )

        XCTAssertTrue(result.words.contains(where: { $0.item == "run" }))
        XCTAssertFalse(result.words.contains(where: { $0.item == "running" }))
        XCTAssertFalse(result.words.contains(where: { $0.item == "runs" }))
    }

    func testKeywordSuiteAnalyzerSupportsChiSquareStatistic() {
        let result = KeywordSuiteAnalyzer.analyze(
            makeRequest(direction: .positive, statistic: .chiSquare)
        )

        XCTAssertEqual(result.words.map(\.item), ["apple"])
        XCTAssertTrue((result.words.first?.keynessScore ?? 0) > 0)
    }

    func testKeywordSuiteAnalyzerHonorsStopwordExcludeAndIncludeModes() {
        let excludeResult = KeywordSuiteAnalyzer.analyze(
            makeRequest(
                direction: .both,
                stopwordFilter: StopwordFilterState(
                    enabled: true,
                    mode: .exclude,
                    listText: "apple"
                ),
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: "focus",
                        corpusName: "Focus",
                        folderName: "Default",
                        content: "apple apple banana grape"
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: "reference",
                        corpusName: "Reference",
                        folderName: "Default",
                        content: "banana banana grape"
                    )
                ]
            )
        )

        XCTAssertFalse(excludeResult.words.contains(where: { $0.item == "apple" }))
        XCTAssertTrue(excludeResult.words.contains(where: { $0.item == "banana" }))

        let includeResult = KeywordSuiteAnalyzer.analyze(
            makeRequest(
                direction: .positive,
                languagePreset: .mixedChineseEnglish,
                scripts: [.latin],
                stopwordFilter: StopwordFilterState(
                    enabled: true,
                    mode: .include,
                    listText: "apple\nbanana"
                ),
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: "focus",
                        corpusName: "Focus",
                        folderName: "Default",
                        content: "apple apple banana 苹果"
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: "reference",
                        corpusName: "Reference",
                        folderName: "Default",
                        content: "apple banana banana 苹果"
                    )
                ]
            )
        )

        XCTAssertEqual(includeResult.words.map(\.item), ["apple"])
    }

    func testKeywordSuiteAnalyzerComputesFocusAndReferenceRangesAcrossPooledCorpora() {
        let result = KeywordSuiteAnalyzer.analyze(
            makeRequest(
                direction: .both,
                focusEntries: [
                    KeywordRequestEntry(
                        corpusId: "focus-a",
                        corpusName: "Focus A",
                        folderName: "Default",
                        content: "apple apple"
                    ),
                    KeywordRequestEntry(
                        corpusId: "focus-b",
                        corpusName: "Focus B",
                        folderName: "Default",
                        content: "apple banana"
                    )
                ],
                referenceEntries: [
                    KeywordRequestEntry(
                        corpusId: "ref-a",
                        corpusName: "Reference A",
                        folderName: "Default",
                        content: "apple"
                    ),
                    KeywordRequestEntry(
                        corpusId: "ref-b",
                        corpusName: "Reference B",
                        folderName: "Default",
                        content: "banana banana"
                    )
                ]
            )
        )

        XCTAssertEqual(result.words.first(where: { $0.item == "apple" })?.focusRange, 2)
        XCTAssertEqual(result.words.first(where: { $0.item == "apple" })?.referenceRange, 1)
        XCTAssertEqual(result.words.first(where: { $0.item == "banana" })?.focusRange, 1)
        XCTAssertEqual(result.words.first(where: { $0.item == "banana" })?.referenceRange, 1)
    }

    func testLegacyKeywordAnalyzerMatchesSuiteWordsForPositiveResults() {
        let focus = makeFocusEntry()
        let reference = makeReferenceEntry()
        let options = KeywordPreprocessingOptions(
            lowercased: true,
            removePunctuation: true,
            stopwordFilter: .default,
            minimumFrequency: 1,
            statistic: .logLikelihood
        )

        let legacyResult = KeywordSuiteAnalyzer.legacyAnalyze(
            target: focus,
            reference: reference,
            options: options
        )
        let suiteResult = KeywordSuiteAnalyzer.analyze(
            KeywordSuiteRunRequest(
                focusEntries: [focus],
                referenceEntries: [reference],
                importedReferenceItems: [],
                focusLabel: focus.corpusName,
                referenceLabel: reference.corpusName,
                configuration: .legacy(
                    targetCorpusID: focus.corpusId,
                    referenceCorpusID: reference.corpusId,
                    options: options
                )
            )
        )

        XCTAssertEqual(legacyResult.rows.map(\.word), suiteResult.words.map(\.item))
        XCTAssertEqual(legacyResult.rows.map(\.targetFrequency), suiteResult.words.map(\.focusFrequency))
        XCTAssertEqual(legacyResult.rows.map(\.referenceFrequency), suiteResult.words.map(\.referenceFrequency))
        XCTAssertEqual(legacyResult.rows.map(\.keynessScore), suiteResult.words.map(\.keynessScore))
    }

    func testWorkspaceSnapshotMigratesLegacyKeywordFieldsIntoSuiteConfiguration() {
        let snapshot = WorkspaceSnapshotSummary(json: [
            "currentTab": "keyword",
            "currentLibraryFolderId": "all",
            "workspace": [
                "corpusIds": ["corpus-1"],
                "corpusNames": ["Focus Corpus"]
            ],
            "search": [
                "query": "",
                "options": SearchOptionsState.default.asJSONObject(),
                "stopwordFilter": StopwordFilterState.default.asJSONObject()
            ],
            "keyword": [
                "targetCorpusID": "corpus-1",
                "referenceCorpusID": "corpus-2",
                "lowercased": true,
                "removePunctuation": true,
                "minimumFrequency": "3",
                "statistic": KeywordStatisticMethod.chiSquare.rawValue,
                "stopwordFilter": StopwordFilterState.default.asJSONObject()
            ]
        ])

        XCTAssertEqual(snapshot.keywordActiveTab, .words)
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.focusSelection.kind, .singleCorpus)
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.focusSelection.corpusIDs, ["corpus-1"])
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.referenceSource.kind, .singleCorpus)
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.referenceSource.corpusID, "corpus-2")
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.statistic, .chiSquare)
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.thresholds.minFocusFreq, 3)
        XCTAssertEqual(snapshot.keywordSuiteConfiguration.thresholds.minCombinedFreq, 3)
    }

    private func makeRequest(
        direction: KeywordDirection,
        unit: KeywordUnit = .normalizedSurface,
        statistic: KeywordStatisticMethod = .logLikelihood,
        languagePreset: TokenizeLanguagePreset = .latinFocused,
        scripts: [TokenScript] = [],
        stopwordFilter: StopwordFilterState = .default,
        focusEntries: [KeywordRequestEntry]? = nil,
        referenceEntries: [KeywordRequestEntry]? = nil
    ) -> KeywordSuiteRunRequest {
        let resolvedFocusEntries = focusEntries ?? [makeFocusEntry()]
        let resolvedReferenceEntries = referenceEntries ?? [makeReferenceEntry()]
        return KeywordSuiteRunRequest(
            focusEntries: resolvedFocusEntries,
            referenceEntries: resolvedReferenceEntries,
            importedReferenceItems: [],
            focusLabel: "Focus",
            referenceLabel: "Reference",
            configuration: makeConfiguration(
                direction: direction,
                unit: unit,
                statistic: statistic,
                languagePreset: languagePreset,
                scripts: scripts,
                stopwordFilter: stopwordFilter
            )
        )
    }

    private func makeConfiguration(
        direction: KeywordDirection,
        unit: KeywordUnit = .normalizedSurface,
        statistic: KeywordStatisticMethod = .logLikelihood,
        languagePreset: TokenizeLanguagePreset = .latinFocused,
        scripts: [TokenScript] = [],
        stopwordFilter: StopwordFilterState = .default
    ) -> KeywordSuiteConfiguration {
        KeywordSuiteConfiguration(
            focusSelection: KeywordTargetSelection(kind: .singleCorpus, corpusIDs: ["focus"]),
            referenceSource: KeywordReferenceSource(kind: .singleCorpus, corpusID: "reference"),
            unit: unit,
            direction: direction,
            statistic: statistic,
            thresholds: KeywordThresholds(
                minFocusFreq: 0,
                minReferenceFreq: 0,
                minCombinedFreq: 1,
                maxPValue: 1,
                minAbsLogRatio: 0
            ),
            tokenFilters: KeywordTokenFilterState(
                languagePreset: languagePreset,
                lemmaStrategy: unit.lemmaStrategy,
                scripts: scripts,
                lexicalClasses: [],
                stopwordFilter: stopwordFilter
            )
        )
    }

    private func makeFocusEntry() -> KeywordRequestEntry {
        KeywordRequestEntry(
            corpusId: "focus",
            corpusName: "Focus",
            folderName: "Default",
            content: "apple apple apple banana"
        )
    }

    private func makeReferenceEntry() -> KeywordRequestEntry {
        KeywordRequestEntry(
            corpusId: "reference",
            corpusName: "Reference",
            folderName: "Default",
            content: "banana banana banana apple"
        )
    }
}
