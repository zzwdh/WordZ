import Foundation

struct EvidenceWorkbenchGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    let assignmentValue: String?
    let itemCountSummary: String
    let items: [EvidenceItem]
}

enum EvidenceWorkbenchGroupingSupport {
    static func makeGroups(
        items: [EvidenceItem],
        grouping: EvidenceWorkbenchGroupingMode,
        mode: AppLanguageMode
    ) -> [EvidenceWorkbenchGroup] {
        var orderedIDs: [String] = []
        var groupedItems: [String: [EvidenceItem]] = [:]
        var descriptors: [String: (title: String, subtitle: String?, assignmentValue: String?)] = [:]

        for item in items {
            let descriptor = descriptor(for: item, grouping: grouping, mode: mode)
            if groupedItems[descriptor.id] == nil {
                orderedIDs.append(descriptor.id)
                descriptors[descriptor.id] = (
                    descriptor.title,
                    descriptor.subtitle,
                    descriptor.assignmentValue
                )
            }
            groupedItems[descriptor.id, default: []].append(item)
        }

        return orderedIDs.compactMap { id in
            guard let items = groupedItems[id],
                  let descriptor = descriptors[id]
            else { return nil }
            return EvidenceWorkbenchGroup(
                id: id,
                title: descriptor.title,
                subtitle: descriptor.subtitle,
                assignmentValue: descriptor.assignmentValue,
                itemCountSummary: String(
                    format: wordZText("%d 条证据", "%d items", mode: mode),
                    items.count
                ),
                items: items
            )
        }
    }

    static func groupID(
        for item: EvidenceItem,
        grouping: EvidenceWorkbenchGroupingMode
    ) -> String {
        descriptor(for: item, grouping: grouping, mode: .system).id
    }

    static func assignmentValue(
        for item: EvidenceItem,
        grouping: EvidenceWorkbenchGroupingMode
    ) -> String? {
        descriptor(for: item, grouping: grouping, mode: .system).assignmentValue
    }

    private static func descriptor(
        for item: EvidenceItem,
        grouping: EvidenceWorkbenchGroupingMode,
        mode: AppLanguageMode
    ) -> (id: String, title: String, subtitle: String?, assignmentValue: String?) {
        switch grouping {
        case .section:
            if let title = normalizedValue(item.sectionTitle) {
                return ("section:\(title)", title, normalizedValue(item.claim), title)
            }
            return (
                "section:__unsectioned__",
                wordZText("未分组章节", "Unsectioned", mode: mode),
                normalizedValue(item.claim),
                nil
            )
        case .claim:
            if let title = normalizedValue(item.claim) {
                return ("claim:\(title)", title, normalizedValue(item.sectionTitle), title)
            }
            return (
                "claim:__unclaimed__",
                wordZText("未归类论点", "Unclaimed", mode: mode),
                normalizedValue(item.sectionTitle),
                nil
            )
        case .corpusSet:
            if let savedSetName = normalizedValue(item.savedSetName) {
                let subtitle = normalizedValue(item.corpusName)
                return ("corpus-set:\(savedSetName)", savedSetName, subtitle, savedSetName)
            }
            if let title = normalizedValue(item.corpusName) {
                return ("corpus:\(title)", title, nil, title)
            }
            return (
                "corpus:__untitled__",
                wordZText("未命名语料", "Untitled Corpus", mode: mode),
                nil,
                nil
            )
        }
    }

    private static func normalizedValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
