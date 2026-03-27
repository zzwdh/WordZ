import AppKit
import XCTest
@testable import WordZMac

@MainActor
final class NativeWindowDocumentControllerTests: XCTestCase {
    func testSyncAppliesTitleRepresentedURLAndEditedFlag() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        let controller = NativeWindowDocumentController()
        controller.attach(window: window)

        controller.sync(
            displayName: " Demo Corpus ",
            representedPath: "/tmp/demo.txt",
            edited: true
        )

        XCTAssertEqual(window.title, "Demo Corpus")
        XCTAssertEqual(window.representedURL?.path, "/tmp/demo.txt")
        XCTAssertTrue(window.isDocumentEdited)
    }

    func testSyncClearsRepresentedURLWhenPathIsEmpty() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.representedURL = URL(fileURLWithPath: "/tmp/old.txt")
        let controller = NativeWindowDocumentController()
        controller.attach(window: window)

        controller.sync(
            displayName: "",
            representedPath: "   ",
            edited: false
        )

        XCTAssertNil(window.representedURL)
        XCTAssertFalse(window.isDocumentEdited)
    }
}
