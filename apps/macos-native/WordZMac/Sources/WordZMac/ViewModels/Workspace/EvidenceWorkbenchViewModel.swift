import Foundation

@MainActor
package final class EvidenceWorkbenchViewModel: ObservableObject {
    @Published var items: [EvidenceItem] = []
    @Published var selectedItemID: String? {
        didSet {
            guard oldValue != selectedItemID else { return }
            syncEditorState()
        }
    }
    @Published var reviewFilter: EvidenceReviewFilter = .all {
        didSet {
            guard oldValue != reviewFilter else { return }
            normalizeSelection()
            syncEditorState()
        }
    }
    @Published var citationFormatDraft: EvidenceCitationFormat = .citationLine
    @Published var citationStyleDraft: EvidenceCitationStyle = .plain
    @Published var noteDraft = ""

    package static func makeFeaturePage() -> EvidenceWorkbenchViewModel {
        EvidenceWorkbenchViewModel()
    }

    init() {}

    var filteredItems: [EvidenceItem] {
        items.filter { includesInActiveFilters($0) }
    }

    var hasActiveNarrowingFilters: Bool {
        reviewFilter != .all
    }

    var hasVisibleKeptItems: Bool {
        filteredItems.contains { $0.reviewStatus == .keep }
    }

    func clearFilters() {
        reviewFilter = .all
        normalizeSelection()
        syncEditorState()
    }

    func includesInActiveFilters(_ item: EvidenceItem) -> Bool {
        reviewFilter.includes(item.reviewStatus)
    }

    var hasUnsavedDetailChanges: Bool {
        citationFormatDraft != (selectedItem?.citationFormat ?? .citationLine) ||
            citationStyleDraft != (selectedItem?.citationStyle ?? .plain) ||
            normalizedText(noteDraft) != normalizedText(selectedItem?.note)
    }

    var hasUnsavedNoteChanges: Bool {
        hasUnsavedDetailChanges
    }

    func normalizedNote(_ value: String?) -> String? {
        normalizedText(value)
    }

    func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
