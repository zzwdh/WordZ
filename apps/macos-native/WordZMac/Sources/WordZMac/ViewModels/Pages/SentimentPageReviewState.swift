import Foundation

struct SentimentPageReviewState {
    var rawResult: SentimentRunResult?
    var presentationResult: SentimentPresentationResult?
    var reviewSamples: [SentimentReviewSample] = []

    var result: SentimentRunResult? {
        rawResult
    }

    func selectedEffectiveRow(selectedRowID: String?) -> SentimentEffectiveRow? {
        guard let presentationResult else { return nil }
        if let selectedRowID,
           let row = presentationResult.effectiveRows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return presentationResult.effectiveRows.first
    }

    func selectedResultRow(selectedRowID: String?) -> SentimentRowResult? {
        guard let rawResult else { return nil }
        if let selectedRowID,
           let row = rawResult.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return rawResult.rows.first
    }

    func selectedReviewSample(selectedRowID: String?) -> SentimentReviewSample? {
        guard let selectedResultRow = selectedResultRow(selectedRowID: selectedRowID),
              let rawResult
        else { return nil }
        let matchKey = SentimentReviewMatchKey.make(request: rawResult.request, row: selectedResultRow)
        return reviewSamples
            .filter { $0.matchKey == matchKey }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.id < rhs.id
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    func makeSelectedReviewSample(
        decision: SentimentReviewDecision,
        selectedRowID: String?,
        note: String,
        timestamp: String
    ) -> SentimentReviewSample? {
        guard let selectedResultRow = selectedResultRow(selectedRowID: selectedRowID),
              let rawResult
        else { return nil }
        return SentimentReviewOverlaySupport.makeReviewSample(
            decision: decision,
            row: selectedResultRow,
            result: rawResult,
            note: note,
            timestamp: timestamp,
            existingSample: selectedReviewSample(selectedRowID: selectedRowID)
        )
    }

    mutating func replaceReviewSamples(_ samples: [SentimentReviewSample]) {
        reviewSamples = Self.latestReviewSamples(samples)
    }

    mutating func rebuildPresentationResult() {
        presentationResult = rawResult.map { rawResult in
            SentimentReviewOverlaySupport.makePresentationResult(
                rawResult: rawResult,
                reviewSamples: reviewSamples
            )
        }
    }

    mutating func reset() {
        rawResult = nil
        presentationResult = nil
        reviewSamples = []
    }

    private static func latestReviewSamples(_ samples: [SentimentReviewSample]) -> [SentimentReviewSample] {
        let grouped = Dictionary(grouping: samples, by: \.matchKey)
        return grouped.values.compactMap { group in
            group.max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.id < rhs.id
                }
                return lhs.updatedAt < rhs.updatedAt
            }
        }
        .sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.id > rhs.id
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }
}
