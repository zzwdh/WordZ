import SwiftUI

extension SentimentView {
    func color(for label: SentimentLabel) -> Color {
        WorkbenchChartPalette.sentiment(label)
    }

    func format(_ value: Double) -> String {
        String(format: "%.3f", value)
    }

    func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    func importedBundleSubtitle(_ bundle: SentimentUserLexiconBundle) -> String {
        var components = [
            "v\(bundle.manifest.version)",
            "\(bundle.entries.count) \(t("条规则", "rules"))"
        ]
        let author = bundle.manifest.author.trimmingCharacters(in: .whitespacesAndNewlines)
        if !author.isEmpty {
            components.append(author)
        }
        let notes = bundle.manifest.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !notes.isEmpty {
            components.append(notes)
        }
        return components.joined(separator: " · ")
    }

    func aggregationTitle(for mode: SentimentAggregationMode) -> String {
        switch mode {
        case .direct:
            return t("直接判别", "Direct classification")
        case .sentenceMean:
            return t("句级平均", "Sentence mean")
        }
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
