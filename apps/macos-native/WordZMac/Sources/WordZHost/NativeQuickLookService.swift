import AppKit
import Foundation
@preconcurrency import QuickLookUI

@MainActor
package protocol NativeQuickLookServicing: AnyObject {
    func preview(path: String) throws
}

@MainActor
package final class NativeQuickLookService: NSObject, NativeQuickLookServicing {
    private var previewItems: [NSURL] = []

    package override init() {
        super.init()
    }

    package func preview(path: String) throws {
        let trimmedPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPath.isEmpty else {
            throw NSError(
                domain: "WordZHost.NativeQuickLookService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "当前没有可预览的文件。"]
            )
        }

        let url = URL(fileURLWithPath: trimmedPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw NSError(
                domain: "WordZHost.NativeQuickLookService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "要预览的文件不存在。"]
            )
        }

        previewItems = [url as NSURL]
        guard let panel = QLPreviewPanel.shared() else {
            throw NSError(
                domain: "WordZHost.NativeQuickLookService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "当前无法打开 Quick Look 预览。"]
            )
        }

        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.makeKeyAndOrderFront(nil)
    }
}

extension NativeQuickLookService: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    nonisolated package func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated {
            previewItems.count
        }
    }

    nonisolated package func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        MainActor.assumeIsolated {
            previewItems[index]
        }
    }
}
