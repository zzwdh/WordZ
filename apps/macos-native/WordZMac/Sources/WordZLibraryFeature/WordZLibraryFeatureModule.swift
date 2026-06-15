import Foundation

package enum LibraryFeatureSurface: String, CaseIterable, Sendable {
    case management = "library-management"
}

package enum WordZLibraryFeatureModule {
    package static let identifier = "library"
    package static let activatedSurfaces = LibraryFeatureSurface.allCases
    package static let managementRouteID = LibraryFeatureSurface.management.rawValue

    package static var activationSummary: String {
        activatedSurfaces.map(\.rawValue).joined(separator: ",")
    }
}
