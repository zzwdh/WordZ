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
            return wordZText("已上移摘录。", "Moved the excerpt up.", mode: mode)
        case .down:
            return wordZText("已下移摘录。", "Moved the excerpt down.", mode: mode)
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

struct EvidenceCaptureDraft: Equatable, Sendable {
    var citationFormat: EvidenceCitationFormat
    var citationStyle: EvidenceCitationStyle
    var note: String

    init(
        citationFormat: EvidenceCitationFormat = .citationLine,
        citationStyle: EvidenceCitationStyle = .plain,
        note: String = ""
    ) {
        self.citationFormat = citationFormat
        self.citationStyle = citationStyle
        self.note = note
    }

    var normalizedNote: String? {
        Self.normalizedText(note)
    }

    private static func normalizedText(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
