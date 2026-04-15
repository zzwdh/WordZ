import XCTest
@testable import WordZWorkspaceCore

final class MetadataSuggestionSupportTests: XCTestCase {
    func testMetadataSourcePresetSupportMaintainsRecentSourcesAsLRU() {
        let updated = MetadataSourcePresetSupport.updatedRecentSourceLabels(
            current: ["期刊", "教材", "新闻", "访谈", "小说", "学术", "访谈稿", "播客"],
            newLabel: "教材"
        )

        XCTAssertEqual(updated, ["教材", "期刊", "新闻", "访谈", "小说", "学术", "访谈稿", "播客"])
    }

    func testMetadataYearSuggestionSupportBuildsNumericAndLabelSuggestions() {
        let corpora = [
            LibraryCorpusItem(json: [
                "id": "corpus-1",
                "name": "A",
                "folderId": "folder-1",
                "folderName": "Default",
                "sourceType": "txt",
                "metadata": [
                    "yearLabel": "2024"
                ]
            ]),
            LibraryCorpusItem(json: [
                "id": "corpus-2",
                "name": "B",
                "folderId": "folder-1",
                "folderName": "Default",
                "sourceType": "txt",
                "metadata": [
                    "yearLabel": "2018-2020"
                ]
            ]),
            LibraryCorpusItem(json: [
                "id": "corpus-3",
                "name": "C",
                "folderId": "folder-1",
                "folderName": "Default",
                "sourceType": "txt",
                "metadata": [
                    "yearLabel": "2024年春季"
                ]
            ]),
            LibraryCorpusItem(json: [
                "id": "corpus-4",
                "name": "D",
                "folderId": "folder-1",
                "folderName": "Default",
                "sourceType": "txt",
                "metadata": [
                    "yearLabel": "2024"
                ]
            ])
        ]

        XCTAssertEqual(
            MetadataYearSuggestionSupport.suggestedYears(from: corpora),
            ["2024", "2020", "2018"]
        )
        XCTAssertEqual(
            MetadataYearSuggestionSupport.commonYearLabels(from: corpora),
            ["2024", "2024年春季", "2018-2020"]
        )
    }

    func testMetadataYearSuggestionSupportBuildsQuickRangesFromReferenceDate() throws {
        let formatter = ISO8601DateFormatter()
        let referenceDate = try XCTUnwrap(formatter.date(from: "2026-04-10T00:00:00Z"))

        XCTAssertEqual(
            MetadataYearSuggestionSupport.quickYearLabels(referenceDate: referenceDate),
            ["2026", "2025", "2024", "2023", "2022"]
        )
        XCTAssertEqual(
            MetadataYearSuggestionSupport.rangeShortcuts(referenceDate: referenceDate),
            [
                MetadataYearRangeShortcut(kind: .currentYear, from: "2026", to: "2026"),
                MetadataYearRangeShortcut(kind: .recentThreeYears, from: "2024", to: "2026"),
                MetadataYearRangeShortcut(kind: .recentFiveYears, from: "2022", to: "2026")
            ]
        )
    }
}
