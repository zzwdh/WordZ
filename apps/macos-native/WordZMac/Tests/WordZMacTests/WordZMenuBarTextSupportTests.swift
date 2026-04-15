import XCTest
@testable import WordZWorkspaceCore

final class WordZMenuBarTextSupportTests: XCTestCase {
    func testMenuLabelLeavesShortTitlesUntouched() {
        XCTAssertEqual(
            WordZMenuBarTextSupport.menuLabel("Quick Look Current Content"),
            "Quick Look Current Content"
        )
    }

    func testMenuLabelCollapsesWhitespaceBeforeRendering() {
        XCTAssertEqual(
            WordZMenuBarTextSupport.menuLabel("  当前语料：\n  Demo   Corpus  "),
            "当前语料： Demo Corpus"
        )
    }

    func testMenuLabelTruncatesLongTitlesToThirtyCharacters() {
        XCTAssertEqual(
            WordZMenuBarTextSupport.menuLabel("12345678901234567890123456789012345"),
            "123456789012345678901234567..."
        )
    }
}
