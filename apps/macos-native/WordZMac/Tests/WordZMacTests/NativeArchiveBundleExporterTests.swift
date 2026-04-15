import XCTest
@testable import WordZWorkspaceCore

final class NativeArchiveBundleExporterTests: XCTestCase {
    func testExportArchiveCopiesSourceIntoDestination() throws {
        let sourceDirectoryURL = makeTemporaryDirectory(prefix: "WordZArchiveExporterSource")
        let destinationDirectoryURL = makeTemporaryDirectory(prefix: "WordZArchiveExporterDestination")
        let sourceURL = sourceDirectoryURL.appendingPathComponent("bundle.zip")
        let destinationURL = destinationDirectoryURL.appendingPathComponent("nested/exported.zip")
        try Data("archive-data".utf8).write(to: sourceURL)

        try NativeArchiveBundleExporter().exportArchive(at: sourceURL, to: destinationURL)

        XCTAssertEqual(try Data(contentsOf: destinationURL), Data("archive-data".utf8))
    }

    func testExportArchiveReplacesExistingDestination() throws {
        let sourceDirectoryURL = makeTemporaryDirectory(prefix: "WordZArchiveExporterSource")
        let destinationDirectoryURL = makeTemporaryDirectory(prefix: "WordZArchiveExporterDestination")
        let sourceURL = sourceDirectoryURL.appendingPathComponent("bundle.zip")
        let destinationURL = destinationDirectoryURL.appendingPathComponent("exported.zip")
        try Data("new-data".utf8).write(to: sourceURL)
        try Data("old-data".utf8).write(to: destinationURL)

        try NativeArchiveBundleExporter().exportArchive(at: sourceURL, to: destinationURL)

        XCTAssertEqual(try Data(contentsOf: destinationURL), Data("new-data".utf8))
    }

    private func makeTemporaryDirectory(prefix: String) -> URL {
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
