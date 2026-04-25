import XCTest
@testable import WordZWorkspaceCore

final class NativeAnalysisEngineTests: XCTestCase {
    func testAnalysisEngineCacheRemainsStableUnderConcurrentAccess() async throws {
        let engine = NativeAnalysisEngine()
        let text = "Alpha beta gamma. Alpha hackers hacker."

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 {
                group.addTask {
                    _ = engine.runStats(text: text)
                    _ = engine.runTokenize(text: text)
                    _ = engine.runNgram(text: text, n: 2)
                    _ = try engine.runKWIC(
                        text: text,
                        keyword: "alpha",
                        leftWindow: 2,
                        rightWindow: 2,
                        searchOptions: .default
                    )
                    _ = try engine.runCollocate(
                        text: text,
                        keyword: "alpha",
                        leftWindow: 2,
                        rightWindow: 2,
                        minFreq: 1,
                        searchOptions: .default
                    )
                }
            }

            try await group.waitForAll()
        }

        XCTAssertEqual(engine.cachedDocumentCountForTesting, 1)
        XCTAssertEqual(engine.cachedFrequencySummaryCountForTesting, 1)
    }

    func testAnalysisRuntimeReusesParsedDocumentAcrossConcurrentRequests() async throws {
        let runtime = NativeAnalysisRuntime()
        let text = "Alpha beta gamma. Alpha hackers hacker."

        async let stats = runtime.runStats(text: text)
        async let tokenize = runtime.runTokenize(text: text)
        async let ngram = runtime.runNgram(text: text, n: 2)
        async let kwic = runtime.runKWIC(
            text: text,
            keyword: "alpha",
            leftWindow: 2,
            rightWindow: 2,
            searchOptions: .default
        )

        _ = await stats
        _ = await tokenize
        _ = await ngram
        _ = try await kwic

        let cachedDocumentCount = await runtime.cachedDocumentCountForTesting
        XCTAssertEqual(cachedDocumentCount, 1)
    }

    func testAnalysisEngineReusesParsedDocumentAcrossMultipleAnalyses() throws {
        let engine = NativeAnalysisEngine()
        let text = "Alpha beta gamma. Alpha hackers hacker."

        _ = engine.runStats(text: text)
        _ = engine.runNgram(text: text, n: 2)
        _ = try engine.runKWIC(
            text: text,
            keyword: "hacker*",
            leftWindow: 2,
            rightWindow: 2,
            searchOptions: .default
        )
        _ = try engine.runCollocate(
            text: text,
            keyword: "alpha",
            leftWindow: 2,
            rightWindow: 2,
            minFreq: 1,
            searchOptions: .default
        )
        _ = engine.runLocator(text: text, sentenceId: 0, nodeIndex: 0, leftWindow: 1, rightWindow: 1)

        XCTAssertEqual(engine.cachedDocumentCountForTesting, 1)
    }

    func testAnalysisEngineReusesCachedTextForDuplicateCompareEntries() {
        let engine = NativeAnalysisEngine()
        let duplicatedText = "Alpha beta alpha gamma"
        let result = engine.runCompare(comparisonEntries: [
            CompareRequestEntry(
                corpusId: "corpus-1",
                corpusName: "A",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: duplicatedText
            ),
            CompareRequestEntry(
                corpusId: "corpus-2",
                corpusName: "B",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: duplicatedText
            )
        ])

        XCTAssertEqual(result.corpora.count, 2)
        XCTAssertEqual(engine.cachedDocumentCountForTesting, 1)
    }

    func testKWICDoesNotBuildFrequencySummaryUntilFrequencyDataIsNeeded() throws {
        let engine = NativeAnalysisEngine()
        let text = "Alpha beta gamma. Alpha hackers hacker."

        _ = try engine.runKWIC(
            text: text,
            keyword: "alpha",
            leftWindow: 2,
            rightWindow: 2,
            searchOptions: .default
        )

        XCTAssertEqual(engine.cachedDocumentCountForTesting, 1)
        XCTAssertEqual(engine.cachedFrequencySummaryCountForTesting, 0)

        _ = engine.runStats(text: text)

        XCTAssertEqual(engine.cachedFrequencySummaryCountForTesting, 1)
    }

    func testRunStatsComputesNormFrequencyRangeAndRankPerSentence() {
        let engine = NativeAnalysisEngine()
        let result = engine.runStats(text: "Alpha beta. Gamma alpha alpha!")

        let alpha = result.frequencyRows.first(where: { $0.word == "alpha" })
        let beta = result.frequencyRows.first(where: { $0.word == "beta" })

        XCTAssertEqual(alpha?.count, 3)
        XCTAssertEqual(alpha?.rank, 1)
        XCTAssertEqual(alpha?.range, 2)
        XCTAssertEqual(alpha?.normRange ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(alpha?.normFreq ?? -1, 6_000, accuracy: 0.001)
        XCTAssertEqual(beta?.range, 1)
        XCTAssertEqual(beta?.normRange ?? -1, 50, accuracy: 0.001)
    }

    func testRunTokenizeSplitsSentencesAndNormalizesTokens() {
        let engine = NativeAnalysisEngine()
        let result = engine.runTokenize(text: "Running beta. GAMMA delta!")

        XCTAssertEqual(result.sentenceCount, 2)
        XCTAssertEqual(result.tokenCount, 4)
        XCTAssertEqual(result.sentences.first?.tokens.map(\.original), ["Running", "beta"])
        XCTAssertEqual(result.sentences.last?.tokens.map(\.normalized), ["gamma", "delta"])
        XCTAssertEqual(result.sentences.first?.tokens.first?.annotations.script, .latin)
        XCTAssertEqual(engine.cachedDocumentCountForTesting, 1)
    }

    func testRunStatsTreatsWhitespaceOnlyLineAsParagraphSeparator() {
        let engine = NativeAnalysisEngine()
        let result = engine.runStats(text: "Alpha beta\n   \nGamma delta")

        XCTAssertEqual(result.paragraphCount, 2)
        XCTAssertEqual(result.sentenceCount, 2)
        XCTAssertEqual(result.tokenCount, 4)
    }

    func testRunStatsNormalizesFullWidthTokensIntoSameFrequencyBucket() {
        let engine = NativeAnalysisEngine()
        let result = engine.runStats(text: "ＡＬＰＨＡ alpha beta")

        let alpha = result.frequencyRows.first(where: { $0.word == "alpha" })
        let beta = result.frequencyRows.first(where: { $0.word == "beta" })

        XCTAssertEqual(alpha?.count, 2)
        XCTAssertEqual(beta?.count, 1)
        XCTAssertEqual(result.typeCount, 2)
    }

    func testRunCollocateComputesAssociationMetrics() throws {
        let engine = NativeAnalysisEngine()
        let result = try engine.runCollocate(
            text: "alpha beta alpha beta alpha gamma beta",
            keyword: "alpha",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: .default
        )

        let beta = result.rows.first(where: { $0.word == "beta" })
        let gamma = result.rows.first(where: { $0.word == "gamma" })

        XCTAssertEqual(beta?.total, 4)
        XCTAssertGreaterThan(beta?.logDice ?? 0, gamma?.logDice ?? 0)
        XCTAssertGreaterThan(beta?.tScore ?? 0, 0)
        XCTAssertGreaterThan(beta?.mutualInformation ?? 0, 0)
    }

    func testRunCollocateSupportsPhraseExactMatches() throws {
        let engine = NativeAnalysisEngine()
        let result = try engine.runCollocate(
            text: "alpha beta gamma. alpha delta theta. alpha beta again.",
            keyword: "alpha beta",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: SearchOptionsState(matchMode: .phraseExact)
        )

        XCTAssertEqual(result.rows.first(where: { $0.word == "gamma" })?.total, 1)
        XCTAssertEqual(result.rows.first(where: { $0.word == "again" })?.total, 1)
        XCTAssertNil(result.rows.first(where: { $0.word == "delta" }))
    }

    func testRunCompareComputesSignedKeynessAgainstReferenceCorpora() {
        let engine = NativeAnalysisEngine()
        let result = engine.runCompare(comparisonEntries: [
            CompareRequestEntry(
                corpusId: "corpus-a",
                corpusName: "Target",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: "alpha alpha alpha beta"
            ),
            CompareRequestEntry(
                corpusId: "corpus-b",
                corpusName: "Reference",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: "beta beta beta beta"
            )
        ])

        let alpha = result.rows.first(where: { $0.word == "alpha" })
        let beta = result.rows.first(where: { $0.word == "beta" })

        XCTAssertEqual(alpha?.dominantCorpusName, "Target")
        XCTAssertGreaterThan(alpha?.keyness ?? 0, 0)
        XCTAssertGreaterThan(alpha?.effectSize ?? 0, 0)
        XCTAssertEqual(beta?.dominantCorpusName, "Reference")
        XCTAssertGreaterThan(beta?.keyness ?? 0, 0)
        XCTAssertLessThan(beta?.referenceNormFreq ?? 0, 10_000)
    }

    func testRunSentimentBuildsGroupedSummariesForTargetAndReferenceInputs() {
        let engine = NativeAnalysisEngine()
        let request = SentimentRunRequest(
            source: .corpusCompare,
            unit: .document,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: [
                SentimentInputText(
                    id: "target-1",
                    sourceID: "corpus-1",
                    sourceTitle: "Target Corpus",
                    text: "good excellent",
                    groupID: "target",
                    groupTitle: "Target"
                ),
                SentimentInputText(
                    id: "reference-1",
                    sourceID: "corpus-2",
                    sourceTitle: "Reference Corpus",
                    text: "bad terrible",
                    groupID: "reference",
                    groupTitle: "Reference"
                )
            ],
            backend: .lexicon
        )

        let result = engine.runSentiment(request)

        XCTAssertEqual(result.groupSummaries.count, 2)
        XCTAssertEqual(result.groupSummaries.first(where: { $0.id == "target" })?.positiveCount, 1)
        XCTAssertEqual(result.groupSummaries.first(where: { $0.id == "reference" })?.negativeCount, 1)
        XCTAssertEqual(result.groupSummaries.first(where: { $0.id == "target" })?.totalTexts, 1)
        XCTAssertEqual(result.groupSummaries.first(where: { $0.id == "reference" })?.totalTexts, 1)
    }
}
