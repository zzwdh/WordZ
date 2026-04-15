import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class NativeHostActionServiceTests: XCTestCase {
    func testOpenFileDelegatesToWorkspaceInteraction() async throws {
        let interaction = FakeWorkspaceInteraction()
        let service = NativeHostActionService(
            dialogService: FakeDialogService(),
            workspaceInteraction: interaction
        )

        try await service.openFile(path: "/tmp/report.csv")

        XCTAssertEqual(interaction.openedURLs, [URL(fileURLWithPath: "/tmp/report.csv")])
    }

    func testOpenProjectURLsDelegateToWorkspaceInteraction() async throws {
        let interaction = FakeWorkspaceInteraction()
        let service = NativeHostActionService(
            dialogService: FakeDialogService(),
            workspaceInteraction: interaction
        )

        try await service.openFeedback()
        try await service.openReleaseNotes()
        try await service.openProjectHome()

        XCTAssertEqual(
            interaction.openedURLs.map(\.absoluteString),
            [
                "https://github.com/zzwdh/WordZ/issues/new/choose",
                "https://github.com/zzwdh/WordZ/releases",
                "https://github.com/zzwdh/WordZ"
            ]
        )
    }

    func testOpenURLSurfacesWorkspaceOpenFailure() async {
        let interaction = FakeWorkspaceInteraction()
        interaction.openResults["https://example.com/release"] = false
        let service = NativeHostActionService(
            dialogService: FakeDialogService(),
            workspaceInteraction: interaction
        )

        do {
            try await service.openURL("https://example.com/release")
            XCTFail("Expected URL open failure")
        } catch {
            XCTAssertEqual(interaction.openedURLs.map(\.absoluteString), ["https://example.com/release"])
        }
    }

    func testRevealDownloadedUpdateUsesFileViewer() async throws {
        let interaction = FakeWorkspaceInteraction()
        let service = NativeHostActionService(
            dialogService: FakeDialogService(),
            workspaceInteraction: interaction
        )
        let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WordZHostActionTests-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("WordZ.dmg")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data("demo".utf8).write(to: fileURL)

        try await service.revealDownloadedUpdate(path: fileURL.path)

        XCTAssertEqual(interaction.revealedURLGroups, [[fileURL]])
    }

    func testClipboardAndRecentDocumentActionsDelegateToWorkspaceInteraction() async throws {
        let interaction = FakeWorkspaceInteraction()
        let service = NativeHostActionService(
            dialogService: FakeDialogService(),
            workspaceInteraction: interaction
        )

        try await service.clearRecentDocuments()
        await service.noteRecentDocument(path: "/tmp/demo.txt")
        service.copyTextToClipboard("copied")

        XCTAssertEqual(interaction.clearRecentDocumentsCallCount, 1)
        XCTAssertEqual(interaction.notedRecentDocumentURLs, [URL(fileURLWithPath: "/tmp/demo.txt")])
        XCTAssertEqual(interaction.copiedTexts, ["copied"])
    }

    func testExportArchiveBundleCopiesArchiveToChosenDestination() async throws {
        let interaction = FakeWorkspaceInteraction()
        let dialogService = FakeDialogService()
        let exporter = FakeArchiveBundleExporter()
        let sourceURL = URL(fileURLWithPath: "/tmp/source.zip")
        let destinationURL = URL(fileURLWithPath: "/tmp/exported.zip")
        dialogService.savePathResult = destinationURL.path

        let service = NativeHostActionService(
            dialogService: dialogService,
            workspaceInteraction: interaction,
            archiveBundleExporter: exporter
        )

        let exportedPath = try await service.exportArchiveBundle(
            archivePath: sourceURL.path,
            suggestedName: "WordZ.zip",
            title: "Export Archive",
            preferredRoute: NativeWindowRoute.settings.hostPresentationHint
        )

        XCTAssertEqual(exportedPath, destinationURL.path)
        XCTAssertEqual(dialogService.savePathPreferredRoute, .settings)
        XCTAssertEqual(exporter.exportedPairs.count, 1)
        XCTAssertEqual(exporter.exportedPairs.first?.0, sourceURL)
        XCTAssertEqual(exporter.exportedPairs.first?.1, destinationURL)
    }
}

@MainActor
private final class FakeWorkspaceInteraction: NativeWorkspaceInteractionPerforming {
    var openedURLs: [URL] = []
    var revealedURLGroups: [[URL]] = []
    var clearRecentDocumentsCallCount = 0
    var notedRecentDocumentURLs: [URL] = []
    var terminateCallCount = 0
    var copiedTexts: [String] = []
    var openResults: [String: Bool] = [:]

    func open(_ url: URL) -> Bool {
        openedURLs.append(url)
        return openResults[url.absoluteString] ?? true
    }

    func revealInFileViewer(_ urls: [URL]) {
        revealedURLGroups.append(urls)
    }

    func clearRecentDocuments() {
        clearRecentDocumentsCallCount += 1
    }

    func noteRecentDocument(_ url: URL) {
        notedRecentDocumentURLs.append(url)
    }

    func terminateApplication() {
        terminateCallCount += 1
    }

    func copyTextToClipboard(_ text: String) {
        copiedTexts.append(text)
    }
}

private final class FakeArchiveBundleExporter: NativeArchiveBundleExporting {
    var exportedPairs: [(URL, URL)] = []

    func exportArchive(at sourceURL: URL, to destinationURL: URL) throws {
        exportedPairs.append((sourceURL, destinationURL))
    }
}
