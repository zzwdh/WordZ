import Foundation

@MainActor
final class EvidenceWorkbenchViewModel: ObservableObject {
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
    @Published var noteDraft = ""

    var filteredItems: [EvidenceItem] {
        items.filter { reviewFilter.includes($0.reviewStatus) }
    }

    var selectedItem: EvidenceItem? {
        guard let selectedItemID else { return filteredItems.first }
        return filteredItems.first(where: { $0.id == selectedItemID }) ?? filteredItems.first
    }

    var hasUnsavedNoteChanges: Bool {
        normalizedNote(noteDraft) != normalizedNote(selectedItem?.note)
    }

    func applyItems(_ items: [EvidenceItem]) {
        self.items = items
        normalizeSelection()
        syncEditorState()
    }

    func normalizeSelection() {
        let filteredIDs = Set(filteredItems.map(\.id))
        if let selectedItemID, filteredIDs.contains(selectedItemID) {
            return
        }
        selectedItemID = filteredItems.first?.id
    }

    func syncEditorState() {
        noteDraft = selectedItem?.note ?? ""
    }

    func normalizedNote(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
