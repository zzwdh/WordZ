import XCTest
@testable import WordZWorkspaceCore

final class CorpusMetadataFilterStateTests: XCTestCase {
    func testStructuredYearRangeMatchesEmbeddedYears() {
        let state = CorpusMetadataFilterState(
            sourceQuery: "",
            yearFrom: "2020",
            yearTo: "2024",
            genreQuery: "",
            tagsQuery: ""
        )

        XCTAssertTrue(state.matches(CorpusMetadataProfile(yearLabel: "2018-2020")))
        XCTAssertTrue(state.matches(CorpusMetadataProfile(yearLabel: "2024年春季")))
        XCTAssertFalse(state.matches(CorpusMetadataProfile(yearLabel: "2025")))
    }

    func testStructuredYearRangeNormalizesInvertedBounds() {
        let state = CorpusMetadataFilterState(
            sourceQuery: "",
            yearFrom: "2024",
            yearTo: "2020",
            genreQuery: "",
            tagsQuery: ""
        )

        XCTAssertEqual(state.yearFrom, "2020")
        XCTAssertEqual(state.yearTo, "2024")
        XCTAssertTrue(state.matches(CorpusMetadataProfile(yearLabel: "2021")))
    }

    func testLegacySingleYearQueryMigratesToStructuredRange() {
        let state = CorpusMetadataFilterState(json: [
            "sourceQuery": "",
            "yearQuery": "2024",
            "genreQuery": "",
            "tagsQuery": ""
        ])

        XCTAssertEqual(state.yearQuery, "")
        XCTAssertEqual(state.yearFrom, "2024")
        XCTAssertEqual(state.yearTo, "2024")
        XCTAssertTrue(state.matches(CorpusMetadataProfile(yearLabel: "2024")))
    }

    func testLegacyYearQueryFallsBackToStringContainsMatching() {
        let state = CorpusMetadataFilterState(json: [
            "sourceQuery": "",
            "yearQuery": "春季学期",
            "genreQuery": "",
            "tagsQuery": ""
        ])

        XCTAssertEqual(state.yearQuery, "春季学期")
        XCTAssertNil(state.yearFrom)
        XCTAssertNil(state.yearTo)
        XCTAssertTrue(state.matches(CorpusMetadataProfile(yearLabel: "2024 春季学期")))
        XCTAssertFalse(state.matches(CorpusMetadataProfile(yearLabel: "2024 秋季学期")))
    }

    func testSummaryTextPrioritizesSourceAndStructuredYear() {
        let state = CorpusMetadataFilterState(
            sourceQuery: "教材",
            yearFrom: "2020",
            yearTo: "2024",
            genreQuery: "教学",
            tagsQuery: ""
        )

        XCTAssertEqual(state.summaryText(in: .chinese), "来源：教材 · 年份：2020-2024 · 另 1 项")
    }
}
