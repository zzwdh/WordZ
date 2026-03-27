import Foundation

enum SidebarAction: String, Identifiable, CaseIterable {
    case refresh
    case openSelected

    var id: String { rawValue }
}
