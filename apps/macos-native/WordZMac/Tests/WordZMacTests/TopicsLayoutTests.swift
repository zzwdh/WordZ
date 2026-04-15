import XCTest
@testable import WordZWorkspaceCore

final class TopicsLayoutTests: XCTestCase {
    func testTopicsPaneLayoutUsesStackedLayoutForNarrowWidths() {
        XCTAssertEqual(TopicsPaneLayout.resolve(for: 980), .stacked)
    }

    func testTopicsPaneLayoutUsesTwoColumnsForMediumWidths() {
        XCTAssertEqual(TopicsPaneLayout.resolve(for: 1280), .twoColumn)
    }

    func testTopicsPaneLayoutUsesThreeColumnsForWideWidths() {
        XCTAssertEqual(TopicsPaneLayout.resolve(for: 1680), .threeColumn)
    }

    func testTopicsPaneLayoutsExposeStablePreferredHeights() {
        XCTAssertEqual(TopicsPaneLayout.stacked.preferredHeight, 1_220)
        XCTAssertEqual(TopicsPaneLayout.twoColumn.preferredHeight, 860)
        XCTAssertEqual(TopicsPaneLayout.threeColumn.preferredHeight, 760)
        XCTAssertEqual(TopicsPaneLayout.stacked.segmentsPanePreferredHeight, 520)
        XCTAssertEqual(TopicsPaneLayout.twoColumn.detailsPanePreferredHeight, 320)
    }
}
