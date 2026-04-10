import Foundation

struct RecentDocumentItem: Codable, Equatable, Identifiable {
    let id: String
    let corpusID: String
    let title: String
    let subtitle: String
    let representedPath: String
    let lastOpenedAt: String

    init(
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
