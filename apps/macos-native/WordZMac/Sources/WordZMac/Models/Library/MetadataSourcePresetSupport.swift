import Foundation

enum MetadataSourcePresetSupport {
    static let builtInSourceLabels = [
        "教材",
        "期刊",
        "新闻",
        "学术",
        "访谈",
        "小说"
    ]

    static let maxRecentSourceLabels = 8

    static func normalizedRecentSourceLabels(_ labels: [String]) -> [String] {
        var normalized: [String] = []
        var seenKeys = Set<String>()

        for label in labels {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = normalizedKey(for: trimmed)
            guard !seenKeys.contains(key) else { continue }

            seenKeys.insert(key)
            normalized.append(trimmed)

            if normalized.count == maxRecentSourceLabels {
                break
            }
        }

        return normalized
    }

    static func updatedRecentSourceLabels(
        current: [String],
        newLabel: String
    ) -> [String] {
        let trimmed = newLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return normalizedRecentSourceLabels(current)
        }

        return normalizedRecentSourceLabels([trimmed] + current)
    }

    static func menuRecentSourceLabels(from recentLabels: [String]) -> [String] {
        let builtInKeys = Set(builtInSourceLabels.map(normalizedKey(for:)))
        return normalizedRecentSourceLabels(recentLabels).filter { !builtInKeys.contains(normalizedKey(for: $0)) }
    }

    private static func normalizedKey(for label: String) -> String {
        label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
