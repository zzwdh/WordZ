import AppKit
import Foundation

@MainActor
protocol NativeSharingServicing: AnyObject {
    func share(paths: [String]) throws
}

@MainActor
final class NativeSharingService: NativeSharingServicing {
    private var activePicker: NSSharingServicePicker?

    func share(paths: [String]) throws {
        let application = NSApplication.shared
        let urls = paths.compactMap { path -> URL? in
            let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPath.isEmpty else { return nil }
            let url = URL(fileURLWithPath: trimmedPath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        guard !urls.isEmpty else {
            throw NSError(
                domain: "WordZMac.NativeSharingService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "当前没有可分享的文件。"]
            )
        }
        let anchorWindow = NativeWindowRouting.window(for: .mainWorkspace) ?? application.keyWindow ?? application.mainWindow
        guard let contentView = anchorWindow?.contentView else {
            throw NSError(
                domain: "WordZMac.NativeSharingService",
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
