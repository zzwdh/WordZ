import Foundation

enum EvidenceWorkbenchGroupingMode: String, CaseIterable, Identifiable, Codable, Sendable, Hashable {
    case section
    case claim
    case corpusSet

    var id: String { rawValue }

    var supportsItemAssignment: Bool {
        switch self {
        case .section, .claim:
            return true
        case .corpusSet:
            return false
        }
    }
}
