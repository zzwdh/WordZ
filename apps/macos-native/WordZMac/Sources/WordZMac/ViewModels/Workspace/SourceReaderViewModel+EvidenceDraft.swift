import Foundation

@MainActor
extension SourceReaderViewModel {
    var currentPreparedCitationText: String? {
        currentEvidencePreviewItem?.styledCitationText(
            format: captureCitationFormat,
            style: captureCitationStyle
        )
    }

    private var currentEvidencePreviewItem: EvidenceItem? {
        guard let context = launchContext,
              let selection = scene?.selection
        else { return nil }

        return EvidenceItem(
            id: "source-reader-preview",
            sourceKind: evidenceSourceKind(for: context.origin),
            savedSetID: nil,
            savedSetName: nil,
            corpusID: normalizedText(context.corpusID) ?? "source-reader",
            corpusName: context.corpusName,
            sentenceId: selection.hit.sentenceId,
            sentenceTokenIndex: nil,
            leftContext: selection.leftContext,
            keyword: selection.keyword,
            rightContext: selection.rightContext,
            fullSentenceText: selection.hit.fullSentenceText,
            citationText: selection.hit.citationText,
            citationFormat: captureCitationFormat,
            citationStyle: captureCitationStyle,
            query: normalizedText(context.query) ?? selection.keyword,
            leftWindow: max(0, context.leftWindow ?? 0),
            rightWindow: max(0, context.rightWindow ?? 0),
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            sectionTitle: currentEvidenceCaptureDraft.normalizedSectionTitle,
            claim: currentEvidenceCaptureDraft.normalizedClaim,
            tags: currentEvidenceCaptureDraft.normalizedTags,
            note: currentEvidenceCaptureDraft.normalizedNote,
            createdAt: "",
            updatedAt: ""
        )
    }

    private func evidenceSourceKind(for origin: SourceReaderOriginFeature) -> EvidenceSourceKind {
        switch origin {
        case .kwic:
            return .kwic
        case .locator:
            return .locator
        case .plot:
            return .plot
        case .sentiment:
            return .sentiment
        case .topics:
            return .topics
        }
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
