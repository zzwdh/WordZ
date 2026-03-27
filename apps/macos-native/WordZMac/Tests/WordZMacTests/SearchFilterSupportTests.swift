import XCTest
@testable import WordZMac

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
}
