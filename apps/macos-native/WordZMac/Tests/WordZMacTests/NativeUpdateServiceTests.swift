import XCTest
@testable import WordZMac

final class NativeUpdateServiceTests: XCTestCase {
    func testReleaseVersionComparatorDetectsNewerVersion() {
        XCTAssertTrue(ReleaseVersionComparator.isNewer("1.1.1", than: "1.1.0"))
        XCTAssertTrue(ReleaseVersionComparator.isNewer("v1.1.0", than: "1.0.9"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.1.0", than: "1.1.0"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.0.2", than: "1.0.10"))
    }

    func testGitHubReleasePayloadParserExtractsReleaseMetadata() {
        let result = GitHubReleasePayloadParser.parse([
            "tag_name": "v1.1.1",
            "name": "WordZ 1.1.1",
            "html_url": "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
            "published_at": "2026-03-26T00:00:00Z",
            "body": """
            # Highlights
            - Native table layout persistence
            - Better update downloads
            """,
            "assets": [
                [
                    "name": "WordZ-1.1.1-mac-arm64.dmg",
                    "browser_download_url": "https://example.com/WordZ-1.1.1.dmg"
                ]
            ]
        ], currentVersion: "1.1.0")

        XCTAssertTrue(result.updateAvailable)
        XCTAssertEqual(result.latestVersion, "v1.1.1")
        XCTAssertEqual(result.releaseTitle, "WordZ 1.1.1")
        XCTAssertEqual(result.publishedAt, "2026-03-26T00:00:00Z")
        XCTAssertEqual(result.releaseNotes, ["Highlights", "Native table layout persistence", "Better update downloads"])
        XCTAssertEqual(result.asset?.name, "WordZ-1.1.1-mac-arm64.dmg")
    }
}
