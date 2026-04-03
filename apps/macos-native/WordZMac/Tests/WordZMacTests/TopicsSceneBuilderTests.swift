import XCTest
@testable import WordZMac

@MainActor
final class TopicsSceneBuilderTests: XCTestCase {
    func testTopicsSceneBuilderBuildsClustersAndSelectedTopicDetails() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalClusters, 2)
        XCTAssertEqual(scene.visibleClusters, 2)
        XCTAssertEqual(scene.selectedClusterID, "topic-1")
        XCTAssertEqual(scene.selectedCluster?.keywords.first?.term, "security")
        XCTAssertEqual(scene.visibleSegments, 2)
        XCTAssertTrue(scene.table.isVisible(TopicsColumnKey.excerpt.rawValue))
    }

    func testTopicsSceneBuilderCanHideOutliers() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            includeOutliers: false,
            selectedClusterID: nil,
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalClusters, 2)
        XCTAssertEqual(scene.visibleClusters, 1)
        XCTAssertFalse(scene.clusters.contains(where: \.isOutlier))
    }

    func testTopicsSceneBuilderFiltersSegmentsByWildcardQuery() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "hack*",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.visibleSegments, 2)
        XCTAssertTrue(scene.tableRows.allSatisfy { ($0.values[TopicsColumnKey.excerpt.rawValue] ?? "").localizedCaseInsensitiveContains("hack") })
    }
}
