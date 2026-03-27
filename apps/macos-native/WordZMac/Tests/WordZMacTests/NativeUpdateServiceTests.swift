import XCTest
@testable import WordZMac

final class NativeUpdateServiceTests: XCTestCase {
    func testReleaseVersionComparatorDetectsNewerVersion() {
        XCTAssertTrue(ReleaseVersionComparator.isNewer("1.0.22", than: "1.0.21"))
        XCTAssertTrue(ReleaseVersionComparator.isNewer("v1.1.0", than: "1.0.9"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.0.21", than: "1.0.21"))
        XCTAssertFalse(ReleaseVersionComparator.isNewer("1.0.2", than: "1.0.10"))
    }

    func testGitHubReleasePayloadParserExtractsReleaseMetadata() {
        let result = GitHubReleasePayloadParser.parse([
            "tag_name": "v1.0.22",
            "name": "WordZ 1.0.22",
            "html_url": "https://github.com/zzwdh/WordZ/releases/tag/v1.0.22",
            "published_at": "2026-03-26T00:00:00Z",
            "body": """
            # Highlights
            - Native table layout persistence
            - Better update downloads
            """,
            "assets": [
                [
                    "name": "WordZ-1.0.22-mac-arm64.dmg",
                    "browser_download_url": "https://example.com/WordZ-1.0.22.dmg"
                ]
            ]
        ], currentVersion: "1.0.21")

        XCTAssertTrue(result.updateAvailable)
        XCTAssertEqual(result.latestVersion, "v1.0.22")
        XCTAssertEqual(result.releaseTitle, "WordZ 1.0.22")
        XCTAssertEqual(result.publishedAt, "2026-03-26T00:00:00Z")
        XCTAssertEqual(result.releaseNotes, ["Highlights", "Native table layout persistence", "Better update downloads"])
        XCTAssertEqual(result.asset?.name, "WordZ-1.0.22-mac-arm64.dmg")
    }
}
