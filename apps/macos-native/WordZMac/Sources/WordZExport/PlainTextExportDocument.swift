import Foundation

package struct PlainTextExportDocument: Equatable, Sendable {
    package let suggestedName: String
    package let text: String
    package let allowedExtension: String

    package init(suggestedName: String, text: String, allowedExtension: String = "txt") {
        self.suggestedName = suggestedName
        self.text = text
        self.allowedExtension = allowedExtension
    }
}
