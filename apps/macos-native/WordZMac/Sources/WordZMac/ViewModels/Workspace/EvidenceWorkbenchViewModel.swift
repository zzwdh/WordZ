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
    @Published var sourceFilter: EvidenceSourceFilter = .all {
        didSet {
            guard oldValue != sourceFilter else { return }
            normalizeSelection()
            syncEditorState()
        }
    }
    @Published var sentimentFilter: EvidenceSentimentFilter = .all {
        didSet {
            guard oldValue != sentimentFilter else { return }
            normalizeSelection()
            syncEditorState()
        }
    }
    @Published var tagFilterQuery = "" {
        didSet {
            guard normalizedLookupKey(oldValue) != normalizedLookupKey(tagFilterQuery) else { return }
            normalizeSelection()
            syncEditorState()
        }
    }
    @Published var corpusFilterQuery = "" {
        didSet {
            guard normalizedLookupKey(oldValue) != normalizedLookupKey(corpusFilterQuery) else { return }
            normalizeSelection()
            syncEditorState()
        }
    }
    @Published var sectionDraft = ""
    @Published var claimDraft = ""
    @Published var tagsDraft = ""
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
        reviewFilter != .all ||
            sourceFilter != .all ||
            sentimentFilter != .all ||
            normalizedText(tagFilterQuery) != nil ||
            normalizedText(corpusFilterQuery) != nil
    }

    var hasVisibleKeptItems: Bool {
        filteredItems.contains { $0.reviewStatus == .keep }
    }

    func clearFilters() {
        reviewFilter = .all
        sourceFilter = .all
        sentimentFilter = .all
        tagFilterQuery = ""
        corpusFilterQuery = ""
        normalizeSelection()
        syncEditorState()
    }

    func includesInActiveFilters(_ item: EvidenceItem) -> Bool {
        reviewFilter.includes(item.reviewStatus) &&
            sourceFilter.includes(item) &&
            sentimentFilter.includes(item) &&
            matchesTagFilter(item) &&
            matchesCorpusFilter(item)
    }

    var hasUnsavedDetailChanges: Bool {
        normalizedText(sectionDraft) != normalizedText(selectedItem?.sectionTitle) ||
            normalizedText(claimDraft) != normalizedText(selectedItem?.claim) ||
            normalizedTags(from: tagsDraft) != normalizedTags(selectedItem?.tags ?? []) ||
            citationFormatDraft != (selectedItem?.citationFormat ?? .citationLine) ||
            citationStyleDraft != (selectedItem?.citationStyle ?? .plain) ||
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
            citationFormat: citationFormatDraft,
            citationStyle: citationStyleDraft,
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

    func normalizedLookupKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func matchesTagFilter(_ item: EvidenceItem) -> Bool {
        let requestedTags = normalizedTags(from: tagFilterQuery)
        guard !requestedTags.isEmpty else { return true }
        let itemTagKeys = Set(item.tags.map(normalizedLookupKey))
        return requestedTags
            .map(normalizedLookupKey)
            .allSatisfy { itemTagKeys.contains($0) }
    }

    private func matchesCorpusFilter(_ item: EvidenceItem) -> Bool {
        guard let query = normalizedText(corpusFilterQuery) else { return true }
        let lookupKey = normalizedLookupKey(query)
        return corpusSearchFields(for: item)
            .map(normalizedLookupKey)
            .contains { $0.contains(lookupKey) }
    }

    private func corpusSearchFields(for item: EvidenceItem) -> [String] {
        var fields = [
            item.corpusID,
            item.corpusName,
            item.savedSetName ?? ""
        ]
        if let metadata = item.corpusMetadata {
            fields.append(metadata.sourceLabel)
            fields.append(metadata.yearLabel)
            fields.append(metadata.genreLabel)
            fields.append(metadata.tagsText)
        }
        return fields.filter { !$0.isEmpty }
    }
}
