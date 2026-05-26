import Foundation

extension LibraryCorpusItem {
    var databaseFileDisplayName: String {
        let storedName = storageFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard storedName.isEmpty else { return storedName }

        let corpusName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !corpusName.isEmpty else { return "corpus.db" }
        return corpusName.lowercased().hasSuffix(".db") ? corpusName : "\(corpusName).db"
    }

    func databaseLocationSummary(mode: AppLanguageMode) -> String {
        let folderLabel = folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? wordZText("未分类", "Unfiled", mode: mode)
            : folderName
        return "\(databaseFileDisplayName) · \(folderLabel)"
    }
}
