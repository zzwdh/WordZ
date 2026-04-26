import Foundation

extension EvidenceWorkbenchViewModel {
    var visibleKeptItems: [EvidenceItem] {
        filteredItems.filter { $0.reviewStatus == .keep }
    }

    var hasMetadataGapsInVisibleKeptItems: Bool {
        metadataGapComponents(for: visibleKeptItems, in: .system).affectedReferenceCount > 0
    }

    func citationReadinessSummary(in mode: AppLanguageMode) -> String {
        let keptItems = visibleKeptItems
        guard !keptItems.isEmpty else {
            return wordZText("暂无保留证据", "No kept evidence", mode: mode)
        }

        return [
            wordZText("格式", "Format", mode: mode) + ": " + citationFormatDistribution(keptItems, in: mode),
            wordZText("样式", "Style", mode: mode) + ": " + citationStyleDistribution(keptItems, in: mode)
        ].joined(separator: " · ")
    }

    func metadataReadinessSummary(in mode: AppLanguageMode) -> String {
        let keptItems = visibleKeptItems
        guard !keptItems.isEmpty else {
            return wordZText("暂无保留证据", "No kept evidence", mode: mode)
        }

        let components = metadataGapComponents(for: keptItems, in: mode)
        guard components.affectedReferenceCount > 0 else {
            return wordZText("元数据完整", "Metadata complete", mode: mode)
        }

        let labels = components.missingLabels.joined(separator: ", ")
        return String(
            format: wordZText("%d 个来源缺少 %@", "%d references missing %@", mode: mode),
            components.affectedReferenceCount,
            labels
        )
    }

    private func citationFormatDistribution(_ items: [EvidenceItem], in mode: AppLanguageMode) -> String {
        let entries = EvidenceCitationFormat.allCases.compactMap { format -> (String, Int)? in
            let count = items.filter { $0.citationFormat == format }.count
            guard count > 0 else { return nil }
            return (format.title(in: mode), count)
        }
        return distributionText(entries, totalCount: items.count)
    }

    private func citationStyleDistribution(_ items: [EvidenceItem], in mode: AppLanguageMode) -> String {
        let entries = EvidenceCitationStyle.allCases.compactMap { style -> (String, Int)? in
            let count = items.filter { $0.citationStyle == style }.count
            guard count > 0 else { return nil }
            return (style.title(in: mode), count)
        }
        return distributionText(entries, totalCount: items.count)
    }

    private func distributionText(_ entries: [(title: String, count: Int)], totalCount: Int) -> String {
        if entries.count == 1, entries[0].count == totalCount {
            return entries[0].title
        }
        return entries.map { "\($0.title) \($0.count)" }.joined(separator: " · ")
    }

    private func metadataGapComponents(
        for items: [EvidenceItem],
        in mode: AppLanguageMode
    ) -> EvidenceMetadataGapComponents {
        var seenKeys = Set<String>()
        var affectedReferenceCount = 0
        var missingLabels: [String] = []
        var seenLabels = Set<String>()

        for item in items {
            let key = metadataReferenceKey(for: item)
            guard seenKeys.insert(key).inserted else { continue }

            let labels = missingMetadataLabels(item.corpusMetadata, in: mode)
            guard !labels.isEmpty else { continue }

            affectedReferenceCount += 1
            for label in labels where seenLabels.insert(label).inserted {
                missingLabels.append(label)
            }
        }

        return EvidenceMetadataGapComponents(
            affectedReferenceCount: affectedReferenceCount,
            missingLabels: missingLabels
        )
    }

    private func metadataReferenceKey(for item: EvidenceItem) -> String {
        [
            item.corpusID,
            item.corpusName,
            item.corpusMetadata?.sourceLabel ?? "",
            item.corpusMetadata?.yearLabel ?? "",
            item.corpusMetadata?.genreLabel ?? "",
            item.corpusMetadata?.tags.joined(separator: ",") ?? ""
        ].joined(separator: "|")
    }

    private func missingMetadataLabels(_ metadata: CorpusMetadataProfile?, in mode: AppLanguageMode) -> [String] {
        var labels: [String] = []
        if normalizedText(metadata?.sourceLabel) == nil {
            labels.append(wordZText("来源标签", "Source Label", mode: mode))
        }
        if normalizedText(metadata?.yearLabel) == nil {
            labels.append(wordZText("年份", "Year", mode: mode))
        }
        if normalizedText(metadata?.genreLabel) == nil {
            labels.append(wordZText("体裁", "Genre", mode: mode))
        }
        return labels
    }
}

private struct EvidenceMetadataGapComponents {
    let affectedReferenceCount: Int
    let missingLabels: [String]
}
