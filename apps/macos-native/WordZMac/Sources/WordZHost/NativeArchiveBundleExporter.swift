import Foundation

package protocol NativeArchiveBundleExporting: AnyObject {
    func exportArchive(at sourceURL: URL, to destinationURL: URL) throws
}

package final class NativeArchiveBundleExporter: NativeArchiveBundleExporting {
    private let fileManager: FileManager

    package init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    package func exportArchive(at sourceURL: URL, to destinationURL: URL) throws {
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
}
