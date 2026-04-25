import Foundation

package enum WorkspaceFeatureVertical: String, CaseIterable, Sendable {
    case topics
    case sentiment
    case evidence
}

package enum WordZWorkspaceFeatureModule {
    package static let activatedVerticals = WorkspaceFeatureVertical.allCases

    package static var activationSummary: String {
        activatedVerticals.map(\.rawValue).joined(separator: ",")
    }
}
