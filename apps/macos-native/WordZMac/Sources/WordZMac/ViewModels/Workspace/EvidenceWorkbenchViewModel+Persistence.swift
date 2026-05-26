import Foundation

extension EvidenceWorkbenchViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        reviewFilter = snapshot.evidenceReviewFilter
        normalizeSelection()
        syncEditorState()
    }

    func exportScopeSummary(in mode: AppLanguageMode) -> String {
        var parts: [String] = []
        if reviewFilter != .all {
            parts.append(wordZText("审阅", "Review", mode: mode) + ": " + reviewFilter.title(in: mode))
        }
        return parts.isEmpty ? wordZText("全部摘录", "All excerpts", mode: mode) : parts.joined(separator: " · ")
    }
}
