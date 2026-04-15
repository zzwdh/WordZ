import Foundation

package struct NativePresentationRouteHint: Hashable, Sendable {
    package let id: String

    package init(id: String) {
        self.id = id
    }
}

@MainActor
package protocol NativeHostActionServicing: AnyObject {
    func openUserDataDirectory(path: String) async throws
    func openFile(path: String) async throws
    func openURL(_ value: String) async throws
    func openFeedback() async throws
    func openReleaseNotes() async throws
    func openProjectHome() async throws
    func quickLook(path: String) async throws
    func share(paths: [String]) async throws
    func openDownloadedUpdate(path: String) async throws
    func openDownloadedUpdateAndTerminate(path: String) async throws
    func revealDownloadedUpdate(path: String) async throws
    func exportArchiveBundle(
        archivePath: String,
        suggestedName: String,
        title: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String?
    func exportDiagnosticBundle(
        archivePath: String,
        suggestedName: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String?
    func clearRecentDocuments() async throws
    func noteRecentDocument(path: String) async
    func copyTextToClipboard(_ text: String)
}
