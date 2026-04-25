import Foundation

extension NativeCorpusStore: SentimentReviewSampleManagingStorage {
    func listSentimentReviewSamples() throws -> [SentimentReviewSample] {
        try ensureInitialized()
        return try loadSentimentReviewSamples()
    }

    func saveSentimentReviewSample(_ sample: SentimentReviewSample) throws -> SentimentReviewSample {
        try ensureInitialized()

        var samples = try loadSentimentReviewSamples()
        let normalized = normalizedSentimentReviewSample(sample)

        if let existingIndex = samples.firstIndex(where: { $0.id == normalized.id || $0.matchKey == normalized.matchKey }) {
            samples[existingIndex] = normalized
        } else {
            samples.insert(normalized, at: 0)
        }

        try saveSentimentReviewSamples(samples)
        return normalized
    }

    func deleteSentimentReviewSample(sampleID: String) throws {
        try ensureInitialized()
        var samples = try loadSentimentReviewSamples()
        guard samples.contains(where: { $0.id == sampleID }) else {
            throw missingItemError("未找到要删除的情感审校样本。")
        }
        samples.removeAll { $0.id == sampleID }
        try saveSentimentReviewSamples(samples)
    }

    func replaceSentimentReviewSamples(_ samples: [SentimentReviewSample]) throws {
        try ensureInitialized()
        var seenKeys: Set<SentimentReviewMatchKey> = []
        var seenIDs: Set<String> = []
        let sanitized = samples.compactMap { sample -> SentimentReviewSample? in
            let normalized = normalizedSentimentReviewSample(sample)
            guard seenIDs.insert(normalized.id).inserted else { return nil }
            guard seenKeys.insert(normalized.matchKey).inserted else { return nil }
            return normalized
        }
        try saveSentimentReviewSamples(sanitized)
    }

    private func normalizedSentimentReviewSample(_ sample: SentimentReviewSample) -> SentimentReviewSample {
        SentimentReviewSample(
            id: sample.id,
            matchKey: sample.matchKey,
            decision: sample.decision,
            rawLabel: sample.rawLabel,
            rawScores: sample.rawScores,
            reviewNote: normalizedSentimentReviewNote(sample.reviewNote),
            createdAt: sample.createdAt,
            updatedAt: sample.updatedAt,
            backendKind: sample.backendKind,
            backendRevision: sample.backendRevision,
            domainPackID: sample.domainPackID,
            ruleProfileID: sample.ruleProfileID,
            calibrationProfileRevision: sample.calibrationProfileRevision,
            activePackIDs: sample.activePackIDs
        )
    }

    private func normalizedSentimentReviewNote(_ note: String?) -> String? {
        guard let note else { return nil }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
