import Foundation

struct PlainTextExportDocument: Equatable, Sendable {
    let suggestedName: String
    let text: String
    let allowedExtension: String

    init(suggestedName: String, text: String, allowedExtension: String = "txt") {
        self.suggestedName = suggestedName
        self.text = text
        self.allowedExtension = allowedExtension
    }
}
