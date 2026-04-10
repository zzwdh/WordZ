import XCTest
@testable import WordZMac

final class NativeAnalysisEngineTests: XCTestCase {
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
}
