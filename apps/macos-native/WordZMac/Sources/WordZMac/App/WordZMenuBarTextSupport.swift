import Foundation

enum WordZMenuBarTextSupport {
    static let maxVisibleCharacters = 30

    static func menuLabel(
        _ rawText: String,
        limit: Int = maxVisibleCharacters
    ) -> String {
        let normalizedText = rawText
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        guard normalizedText.count > limit else {
            return normalizedText
        }
        guard limit > 3 else {
            return String(normalizedText.prefix(max(0, limit)))
        }
        return String(normalizedText.prefix(limit - 3)) + "..."
    }
}
