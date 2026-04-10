import Foundation

enum CompareReferenceSelection: Equatable, Sendable {
    case automatic
    case corpus(String)
    case corpusSet(String)

    init(optionID: String?) {
        let normalized = (optionID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            self = .automatic
            return
        }
        if normalized.hasPrefix("set:") {
            self = .corpusSet(String(normalized.dropFirst(4)))
            return
        }
        self = .corpus(normalized)
    }

    var optionID: String {
        switch self {
        case .automatic:
            return ""
        case .corpus(let corpusID):
            return corpusID
        case .corpusSet(let corpusSetID):
            return "set:\(corpusSetID)"
        }
    }

    var snapshotValue: String {
        optionID
    }

    var corpusID: String? {
        guard case .corpus(let corpusID) = self else { return nil }
        return corpusID
    }

    var corpusSetID: String? {
        guard case .corpusSet(let corpusSetID) = self else { return nil }
        return corpusSetID
    }
}
