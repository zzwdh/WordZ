import Foundation

enum ReadingExportFormat: String, CaseIterable, Equatable, Hashable, Sendable, Identifiable {
    case concordance
    case fullSentence
    case citation
    case summary

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .concordance:
            return wordZText("索引行", "Concordance", mode: mode)
        case .fullSentence:
            return wordZText("完整句", "Full Sentence", mode: mode)
        case .citation:
            return wordZText("引文格式", "Citation", mode: mode)
        case .summary:
            return wordZText("研究摘要", "Research Summary", mode: mode)
        }
    }
}
