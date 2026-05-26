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

    func testRunTokenizeAnnotatesChineseTokensWithoutDroppingEnglishLemmas() {
        let engine = NativeAnalysisEngine()
        let result = engine.runTokenize(text: "WordZ 分析 Chinese corpora 和自然语言。")
        let tokens = result.tokens

        XCTAssertEqual(tokens.first(where: { $0.original == "分析" })?.annotations.script, .cjk)
        XCTAssertEqual(tokens.first(where: { $0.original == "分析" })?.annotations.lexicalClass, .verb)
        XCTAssertEqual(tokens.first(where: { $0.original == "和" })?.annotations.lexicalClass, .conjunction)
        XCTAssertEqual(tokens.first(where: { $0.original == "corpora" })?.annotations.script, .latin)
        XCTAssertEqual(tokens.first(where: { $0.original == "corpora" })?.annotations.lemma, "corpus")
    }

    func testChineseCorpusRunsStatsNgramAndPhraseKWIC() throws {
        let engine = NativeAnalysisEngine()
        let text = "我喜欢自然语言处理。自然语言处理很有用。"

        let stats = engine.runStats(text: text)
        XCTAssertEqual(stats.tokenCount, 8)
        XCTAssertEqual(stats.frequencyRows.first(where: { $0.word == "自然语言" })?.count, 2)
        XCTAssertEqual(stats.frequencyRows.first(where: { $0.word == "处理" })?.count, 2)

        let ngrams = engine.runNgram(text: text, n: 2)
        XCTAssertEqual(ngrams.rows.first(where: { $0.phrase == "自然语言 处理" })?.count, 2)

        let kwic = try engine.runKWIC(
            text: text,
            keyword: "自然语言处理",
            leftWindow: 1,
            rightWindow: 1,
            searchOptions: SearchOptionsState(matchMode: .phraseExact)
        )
        XCTAssertEqual(kwic.rows.count, 2)
        XCTAssertEqual(kwic.rows.first?.node, "自然语言 处理")
    }

    func testChineseCorpusRunsCompareKeywordAndCollocate() throws {
        let engine = NativeAnalysisEngine()
        let targetText = "自然语言处理帮助研究。自然语言处理支持分析。自然语言处理很有用。"
        let referenceText = "课堂教学帮助学生。课堂教学支持学习。课堂教学很有用。"

        let compare = engine.runCompare(comparisonEntries: [
            CompareRequestEntry(
                corpusId: "target",
                corpusName: "中文目标语料",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: targetText
            ),
            CompareRequestEntry(
                corpusId: "reference",
                corpusName: "中文参照语料",
                folderId: "folder-1",
                folderName: "Default",
                sourceType: "txt",
                content: referenceText
            )
        ])
        let compareRow = compare.rows.first(where: { $0.word == "自然语言" })
        XCTAssertEqual(compareRow?.dominantCorpusName, "中文目标语料")
        XCTAssertGreaterThan(compareRow?.keyness ?? 0, 0)

        let keyword = engine.runKeyword(
            targetEntry: KeywordRequestEntry(
                corpusId: "target",
                corpusName: "中文目标语料",
                folderName: "Default",
                content: targetText
            ),
            referenceEntry: KeywordRequestEntry(
                corpusId: "reference",
                corpusName: "中文参照语料",
                folderName: "Default",
                content: referenceText
            ),
            options: KeywordPreprocessingOptions(
                lowercased: true,
                removePunctuation: true,
                stopwordFilter: .default,
                minimumFrequency: 1,
                statistic: .logLikelihood
            )
        )
        let keywordRow = keyword.rows.first(where: { $0.word == "自然语言" })
        XCTAssertEqual(keywordRow?.targetFrequency, 3)
        XCTAssertEqual(keywordRow?.referenceFrequency, 0)
        XCTAssertGreaterThan(keywordRow?.keynessScore ?? 0, 0)

        let collocate = try engine.runCollocate(
            text: targetText,
            keyword: "自然语言处理",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: SearchOptionsState(matchMode: .phraseExact)
        )
        XCTAssertEqual(collocate.rows.first(where: { $0.word == "帮助" })?.total, 1)
        XCTAssertEqual(collocate.rows.first(where: { $0.word == "支持" })?.total, 1)
        XCTAssertEqual(collocate.rows.first(where: { $0.word == "很" })?.total, 1)
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

    func testRunCollocateProducesSameRowsAcrossFastPaths() throws {
        let engine = NativeAnalysisEngine()
        let text = "alpha beta alpha gamma. beta alpha beta."
        let textResult = try engine.runCollocate(
            text: text,
            keyword: "alpha",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: .default
        )
        let tokenized = engine.runTokenize(text: text)
        let artifact = StoredTokenizedArtifact(textDigest: "digest", sentences: tokenized.sentences)
        let positions = tokenized.tokens
            .filter { $0.normalized == "alpha" }
            .map { StoredTokenPosition(sentenceId: $0.sentenceId, tokenIndex: $0.tokenIndex) }

        let positionResult = engine.runCollocate(
            artifact: artifact,
            positions: positions,
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1
        )
        let artifactResult = try engine.runCollocate(
            artifact: artifact,
            keyword: "alpha",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: .default
        )
        let candidateResult = try engine.runCollocate(
            artifact: artifact,
            candidateSentenceIDs: Set(tokenized.sentences.map(\.sentenceId)),
            keyword: "alpha",
            leftWindow: 1,
            rightWindow: 1,
            minFreq: 1,
            searchOptions: .default
        )

        XCTAssertEqual(positionResult.rows, textResult.rows)
        XCTAssertEqual(artifactResult.rows, textResult.rows)
        XCTAssertEqual(candidateResult.rows, textResult.rows)
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
