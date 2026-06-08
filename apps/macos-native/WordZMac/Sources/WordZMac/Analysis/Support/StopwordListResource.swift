import Foundation
import WordZAnalysis

enum StopwordListResource {
    static func loadStopwords(
        named name: String,
        subdirectory: String,
        fallback: String = ""
    ) -> String {
        guard let url = WordZAnalysisResources.bundle.url(
            forResource: name,
            withExtension: "txt",
            subdirectory: subdirectory
        ) else {
            return fallback
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? fallback
    }
}
