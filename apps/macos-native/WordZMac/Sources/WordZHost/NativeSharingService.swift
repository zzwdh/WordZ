import AppKit
import Foundation

@MainActor
package protocol NativeSharingServicing: AnyObject {
    func share(paths: [String]) throws
}

@MainActor
package final class NativeSharingService: NativeSharingServicing {
    private let anchorWindowProvider: @MainActor () -> NSWindow?
    private var activePicker: NSSharingServicePicker?

    package init(
        anchorWindowProvider: @escaping @MainActor () -> NSWindow? = { nil }
    ) {
        self.anchorWindowProvider = anchorWindowProvider
    }

    package func share(paths: [String]) throws {
        let urls = paths.compactMap { path -> URL? in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else { return nil }
            let url = URL(fileURLWithPath: trimmedPath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        guard !urls.isEmpty else {
            throw NSError(
                domain: "WordZHost.NativeSharingService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "当前没有可分享的文件。"]
            )
        }

        let anchorWindow = anchorWindowProvider()
            ?? NSApplication.shared.keyWindow
            ?? NSApplication.shared.mainWindow
        guard let contentView = anchorWindow?.contentView else {
            throw NSError(
                domain: "WordZHost.NativeSharingService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "当前无法显示系统分享菜单。"]
            )
        }

        let picker = NSSharingServicePicker(items: urls)
        activePicker = picker
        let anchor = NSRect(x: contentView.bounds.midX - 1, y: contentView.bounds.maxY - 2, width: 2, height: 2)
        picker.show(relativeTo: anchor, of: contentView, preferredEdge: .minY)
    }
}
