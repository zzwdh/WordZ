import Foundation

package struct RecentDocumentItem: Codable, Equatable, Identifiable {
    package let id: String
    package let corpusID: String
    package let title: String
    package let subtitle: String
    package let representedPath: String
    package let lastOpenedAt: String

    package init(
        id: String = UUID().uuidString,
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String,
        lastOpenedAt: String
    ) {
        self.id = id
        self.corpusID = corpusID
        self.title = title
        self.subtitle = subtitle
        self.representedPath = representedPath
        self.lastOpenedAt = lastOpenedAt
    }
}
