import Foundation

@MainActor
package final class EvidenceWorkbenchViewModel: ObservableObject {
    @Published var items: [EvidenceItem] = []
    @Published var groupingMode: EvidenceWorkbenchGroupingMode = .section
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
    @Published var sectionDraft = ""
    @Published var claimDraft = ""
    @Published var tagsDraft = ""
    @Published var noteDraft = ""

    package static func makeFeaturePage() -> EvidenceWorkbenchViewModel {
        EvidenceWorkbenchViewModel()
    }

    init() {}

    var filteredItems: [EvidenceItem] {
        items.filter { reviewFilter.includes($0.reviewStatus) }
    }

    var hasUnsavedDetailChanges: Bool {
        normalizedText(sectionDraft) != normalizedText(selectedItem?.sectionTitle) ||
            normalizedText(claimDraft) != normalizedText(selectedItem?.claim) ||
            normalizedTags(from: tagsDraft) != normalizedTags(selectedItem?.tags ?? []) ||
            normalizedText(noteDraft) != normalizedText(selectedItem?.note)
    }

    var hasUnsavedNoteChanges: Bool {
        hasUnsavedDetailChanges
    }

    var currentDraft: EvidenceCaptureDraft {
        EvidenceCaptureDraft(
            sectionTitle: sectionDraft,
            claim: claimDraft,
            tagsText: tagsDraft,
            note: noteDraft
        )
    }

    func normalizedNote(_ value: String?) -> String? {
        normalizedText(value)
    }

    func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func normalizedTags(from rawValue: String) -> [String] {
        var seen = Set<String>()
        return rawValue
            .split(separator: ",")
            .compactMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                guard seen.insert(key).inserted else { return nil }
                return trimmed
            }
    }

    func normalizedTags(_ values: [String]) -> [String] {
        normalizedTags(from: values.joined(separator: ", "))
    }
}
