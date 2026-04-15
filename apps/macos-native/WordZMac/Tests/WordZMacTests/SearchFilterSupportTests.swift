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

    func testStopwordListNormalizationDeduplicatesFullWidthVariants() {
        let state = StopwordFilterState(
            enabled: true,
            mode: .exclude,
            listText: "Alpha\nＡＬＰＨＡ\nbeta"
        )

        XCTAssertEqual(state.parsedWords, ["alpha", "beta"])
    }
}
