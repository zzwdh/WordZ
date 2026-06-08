import XCTest
@testable import WordZWorkspaceCore

final class SearchFilterSupportTests: XCTestCase {
    func testWildcardMatcherMatchesTokenPrefixesWithoutRegexMode() {
        let matcher = SearchTextMatcher(
            query: "hacker*",
            options: SearchOptionsState(words: true, caseSensitive: false, regex: false)
        )

        XCTAssertTrue(matcher.matches("hacker"))
        XCTAssertTrue(matcher.matches("hackers"))
        XCTAssertTrue(matcher.matches("HACKERSPACE"))
        XCTAssertFalse(matcher.matches("lifehacker"))
    }

    func testWildcardMatcherSupportsSingleCharacterWildcards() {
        let matcher = SearchTextMatcher(
            query: "hack?r",
            options: SearchOptionsState(words: true, caseSensitive: false, regex: false)
        )

        XCTAssertTrue(matcher.matches("hacker"))
        XCTAssertTrue(matcher.matches("hackor"))
        XCTAssertFalse(matcher.matches("hackers"))
    }

    func testWildcardMatcherRespectsCaseSensitivity() {
        let matcher = SearchTextMatcher(
            query: "Hacker*",
            options: SearchOptionsState(words: true, caseSensitive: true, regex: false)
        )

        XCTAssertTrue(matcher.matches("Hackers"))
        XCTAssertFalse(matcher.matches("hackers"))
    }

    func testRegexModeStillTreatsAsteriskAsRegex() {
        let matcher = SearchTextMatcher(
            query: "hack(er|ers)",
            options: SearchOptionsState(words: true, caseSensitive: false, regex: true)
        )

        XCTAssertTrue(matcher.matches("hacker"))
        XCTAssertTrue(matcher.matches("hackers"))
        XCTAssertFalse(matcher.matches("hacking"))
    }

    func testRegexModeCompilesCaseInsensitiveMatcherOnceAndMatchesUppercaseValues() {
        let matcher = SearchTextMatcher(
            query: "hack(er|ers)",
            options: SearchOptionsState(words: true, caseSensitive: false, regex: true)
        )

        XCTAssertTrue(matcher.matches("HACKER"))
        XCTAssertTrue(matcher.matches("Hackers"))
        XCTAssertFalse(matcher.matches("HACKING"))
    }

    func testFilterWordLikeRowsReturnsOriginalRowsWhenNoFilterIsActive() {
        let rows = ["alpha", "beta", "gamma"]

        let result = SearchFilterSupport.filterWordLikeRows(
            rows,
            query: "",
            options: .default,
            stopword: .default
        ) { $0 }

        XCTAssertEqual(result.error, "")
        XCTAssertEqual(result.rows, rows)
    }

    func testMatcherNormalizesFullWidthTextWhenCaseInsensitive() {
        let matcher = SearchTextMatcher(
            query: "alpha",
            options: SearchOptionsState(words: true, caseSensitive: false, regex: false)
        )

        XCTAssertTrue(matcher.matches("ＡＬＰＨＡ"))
        XCTAssertTrue(matcher.matches("Alpha"))
        XCTAssertFalse(matcher.matches("alphabet"))
    }

    func testExactPhraseMatcherSegmentsChineseQueriesWithoutSpaces() {
        let matcher = SearchTextMatcher(
            query: "自然语言处理",
            options: SearchOptionsState(matchMode: .phraseExact)
        )

        let ranges = matcher.matchingPhraseRanges(in: ["我", "喜欢", "自然语言", "处理"]) { $0 }

        XCTAssertEqual(ranges.map { "\($0.lowerBound)..<\($0.upperBound)" }, ["2..<4"])
    }

    func testTopicFilterTokenizeSegmentsChineseText() {
        let tokens = TopicFilterSupport.tokenize("城市交通系统正在改善公共服务")

        XCTAssertGreaterThan(tokens.count, 1)
        XCTAssertTrue(tokens.contains(where: { $0.contains("交通") }))
        XCTAssertTrue(tokens.contains(where: { $0.contains("服务") }))
    }

    func testStopwordListNormalizationDeduplicatesFullWidthVariants() {
        let state = StopwordFilterState(
            enabled: true,
            mode: .exclude,
            listText: "Alpha\nＡＬＰＨＡ\nbeta"
        )

        XCTAssertEqual(state.parsedWords, ["alpha", "beta"])
    }

    func testChineseStopwordPresetsLoadBundledResources() {
        XCTAssertEqual(StopwordListPreset.englishDefault.parsedWordCount, 850)
        XCTAssertEqual(StopwordFilterState.default.parsedWords.count, 850)
        XCTAssertEqual(StopwordListPreset.chineseGeneral.parsedWordCount, 743)
        XCTAssertEqual(StopwordListPreset.hit.parsedWordCount, 717)
        XCTAssertEqual(StopwordListPreset.baidu.parsedWordCount, 1_392)
        XCTAssertEqual(StopwordListPreset.scu.parsedWordCount, 860)
        XCTAssertEqual(StopwordListPreset.chineseMerged.parsedWordCount, 2_268)

        let mergedWords = Set(StopwordListPreset.chineseMerged.normalizedListText.components(separatedBy: "\n"))
        XCTAssertTrue(mergedWords.contains("的"))
        XCTAssertTrue(mergedWords.contains("一一"))
        XCTAssertTrue(mergedWords.contains("able"))
        XCTAssertTrue(mergedWords.contains("打开天窗说亮话"))
    }
}
