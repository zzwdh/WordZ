import Foundation

enum EvidenceWorkbenchMoveDirection: String, Identifiable, Sendable, Hashable {
    case up
    case down

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .up:
            return wordZText("上移", "Move Up", mode: mode)
        case .down:
            return wordZText("下移", "Move Down", mode: mode)
        }
    }

    func successStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .up:
            return wordZText("已上移证据条目。", "Moved the evidence item up.", mode: mode)
        case .down:
            return wordZText("已下移证据条目。", "Moved the evidence item down.", mode: mode)
        }
    }

    func boundaryStatus(in mode: AppLanguageMode) -> String {
        switch self {
        case .up:
            return wordZText("当前条目已经位于最前。", "The selected item is already at the top.", mode: mode)
        case .down:
            return wordZText("当前条目已经位于最后。", "The selected item is already at the bottom.", mode: mode)
        }
    }

    var systemImageName: String {
        switch self {
        case .up:
            return "arrow.up"
        case .down:
            return "arrow.down"
        }
    }
}

enum EvidenceWorkbenchGroupInsertPlacement: String, Sendable, Hashable {
    case before
    case after
}

struct EvidenceCaptureDraft: Equatable, Sendable {
    var sectionTitle: String
    var claim: String
    var tagsText: String
    var note: String

    init(
        sectionTitle: String = "",
        claim: String = "",
        tagsText: String = "",
        note: String = ""
    ) {
        self.sectionTitle = sectionTitle
        self.claim = claim
        self.tagsText = tagsText
        self.note = note
    }

    var normalizedSectionTitle: String? {
        Self.normalizedText(sectionTitle)
    }

    var normalizedClaim: String? {
        Self.normalizedText(claim)
    }

    var normalizedTags: [String] {
        Self.normalizedTags(tagsText)
    }

    var normalizedNote: String? {
        Self.normalizedText(note)
    }

    var isEmpty: Bool {
        normalizedSectionTitle == nil &&
            normalizedClaim == nil &&
            normalizedTags.isEmpty &&
            normalizedNote == nil
    }

    func summary(in mode: AppLanguageMode) -> String {
        var parts: [String] = []
        if let sectionTitle = normalizedSectionTitle {
            parts.append(wordZText("章节", "Section", mode: mode) + ": " + sectionTitle)
        }
        if let claim = normalizedClaim {
            parts.append(wordZText("论点", "Claim", mode: mode) + ": " + claim)
        }
        if !normalizedTags.isEmpty {
            parts.append(wordZText("标签", "Tags", mode: mode) + ": " + normalizedTags.joined(separator: ", "))
        }
        if normalizedNote != nil {
            parts.append(wordZText("附备注", "With note", mode: mode))
        }
        return parts.joined(separator: " · ")
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func normalizedTags(_ value: String) -> [String] {
        var seen = Set<String>()
        return value
            .split(separator: ",")
            .compactMap { raw in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                let key = trimmed.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                guard seen.insert(key).inserted else { return nil }
                return trimmed
            }
    }
}
