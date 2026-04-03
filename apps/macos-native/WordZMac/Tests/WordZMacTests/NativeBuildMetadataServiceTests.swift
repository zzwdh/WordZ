import XCTest
@testable import WordZMac

final class NativeBuildMetadataServiceTests: XCTestCase {
    func testCurrentPrefersPersistedBuildInfoWhenAvailable() throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDirectory) }

        let buildInfoURL = tempDirectory.appendingPathComponent("WordZMacBuildInfo.json")
        try """
        {
          "appName": "WordZ",
          "bundleIdentifier": "com.zzwdh.wordz.native",
          "version": "1.2.0",
          "buildNumber": "20260403153000",
          "architecture": "arm64",
          "builtAt": "2026-04-03T15:30:00Z",
          "gitCommit": "abcdef1234567890",
          "gitBranch": "codex/wordzSWIFT",
          "distributionChannel": "release",
          "executableSHA256": "deadbeef"
        }
        """.data(using: .utf8)?.write(to: buildInfoURL)

        let metadata = NativeBuildMetadataService(buildInfoURL: buildInfoURL).current()

        XCTAssertEqual(metadata.version, "1.2.0")
        XCTAssertEqual(metadata.buildNumber, "20260403153000")
        XCTAssertEqual(metadata.architecture, "arm64")
        XCTAssertEqual(metadata.gitCommit, "abcdef1234567890")
        XCTAssertEqual(metadata.distributionChannel, "release")
        XCTAssertEqual(metadata.executableSHA256, "deadbeef")
        XCTAssertEqual(metadata.sourceLabel, "WordZMacBuildInfo.json")
        XCTAssertTrue(metadata.buildSummary.contains("arm64"))
        XCTAssertTrue(metadata.buildSummary.contains("v1.2.0"))
    }

    func testCurrentFallsBackWhenBuildInfoFileIsMissing() {
        let metadata = NativeBuildMetadataService(buildInfoURL: URL(fileURLWithPath: "/tmp/does-not-exist-build-info.json")).current()

        XCTAssertEqual(metadata.sourceLabel, "runtime-fallback")
        XCTAssertFalse(metadata.buildSummary.isEmpty)
        XCTAssertFalse(metadata.bundlePath.isEmpty)
    }
}
