import Foundation
@testable import WordZWorkspaceCore

enum SentimentGoldDatasetVersion: String, CaseIterable {
    case v1 = "sentiment-gold-v1"
    case v2 = "sentiment-gold-v2"

    static let latest: SentimentGoldDatasetVersion = .v2
}

enum SentimentGoldSplit: String, Codable, CaseIterable {
    case train
    case validation
    case test
}

struct SentimentGoldExample: Codable, Equatable {
    let id: String
    let split: SentimentGoldSplit
    let domain: String
    let label: SentimentLabel
    let text: String
}

struct SentimentLabelMetrics {
    let precision: Double
    let recall: Double
    let f1: Double
}

struct SentimentBenchmarkReport {
    let exampleCount: Int
    let accuracy: Double
    let macroF1: Double
    let neutralFalsePositiveRate: Double
    let confusion: [SentimentLabel: [SentimentLabel: Int]]
    let perLabel: [SentimentLabel: SentimentLabelMetrics]

    var summaryLine: String {
        String(
            format: "n=%d accuracy=%.3f macroF1=%.3f neutralFPR=%.3f",
            exampleCount,
            accuracy,
            macroF1,
            neutralFalsePositiveRate
        )
    }
}

struct SentimentCalibrationResult {
    let thresholds: SentimentThresholds
    let report: SentimentBenchmarkReport
}

enum SentimentGoldDataset {
    static func load(
        version: SentimentGoldDatasetVersion = .latest,
        filePath: StaticString = #filePath
    ) throws -> [SentimentGoldExample] {
        let fixtureURL = Bundle.module.url(
            forResource: version.rawValue,
            withExtension: "json",
            subdirectory: "Fixtures/Sentiment"
        ) ?? URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Sentiment", isDirectory: true)
            .appendingPathComponent("\(version.rawValue).json")
        let data = try Data(contentsOf: fixtureURL)
        return try JSONDecoder().decode([SentimentGoldExample].self, from: data)
    }
}

enum SentimentBenchmarkHarness {
    static func evaluate(
        examples: [SentimentGoldExample],
        thresholds: SentimentThresholds,
        backend: SentimentBackendKind,
        engine: NativeAnalysisEngine = NativeAnalysisEngine()
    ) -> SentimentBenchmarkReport {
        let request = SentimentRunRequest(
            source: .pastedText,
            unit: .document,
            contextBasis: .visibleContext,
            thresholds: thresholds,
            texts: examples.map {
                SentimentInputText(
                    id: $0.id,
                    sourceTitle: $0.domain,
                    text: $0.text
                )
            },
            backend: backend
        )
        let result = engine.runSentiment(request)
        let predictedByID = Dictionary(uniqueKeysWithValues: result.rows.map { ($0.id, $0.finalLabel) })
        return makeReport(
            gold: examples,
            predictedByID: predictedByID
        )
    }

    static func calibrateLexicon(
        validationExamples: [SentimentGoldExample],
        decisionThresholds: [Double] = [0.2, 0.25, 0.3, 0.35, 0.4],
        minimumEvidenceValues: [Double] = [0.4, 0.6, 0.8, 1.0],
        neutralBiasValues: [Double] = [0.9, 1.0, 1.1, 1.2, 1.3]
    ) -> SentimentCalibrationResult {
        precondition(!validationExamples.isEmpty, "Validation examples must not be empty.")

        var best: SentimentCalibrationResult?
        for decisionThreshold in decisionThresholds {
            for minimumEvidence in minimumEvidenceValues {
                for neutralBias in neutralBiasValues {
                    let thresholds = SentimentThresholds(
                        decisionThreshold: decisionThreshold,
                        minimumEvidence: minimumEvidence,
                        neutralBias: neutralBias
                    )
                    let report = evaluate(
                        examples: validationExamples,
                        thresholds: thresholds,
                        backend: .lexicon
                    )
                    let candidate = SentimentCalibrationResult(
                        thresholds: thresholds,
                        report: report
                    )
                    if isBetter(candidate: candidate, than: best) {
                        best = candidate
                    }
                }
            }
        }

        return best!
    }

    private static func isBetter(
        candidate: SentimentCalibrationResult,
        than currentBest: SentimentCalibrationResult?
    ) -> Bool {
        guard let currentBest else { return true }
        if candidate.report.macroF1 != currentBest.report.macroF1 {
            return candidate.report.macroF1 > currentBest.report.macroF1
        }
        if candidate.report.neutralFalsePositiveRate != currentBest.report.neutralFalsePositiveRate {
            return candidate.report.neutralFalsePositiveRate < currentBest.report.neutralFalsePositiveRate
        }
        return candidate.report.accuracy > currentBest.report.accuracy
    }

    private static func makeReport(
        gold: [SentimentGoldExample],
        predictedByID: [String: SentimentLabel]
    ) -> SentimentBenchmarkReport {
        var confusion = Dictionary(uniqueKeysWithValues: SentimentLabel.allCases.map { goldLabel in
            (goldLabel, Dictionary(uniqueKeysWithValues: SentimentLabel.allCases.map { ($0, 0) }))
        })

        var correct = 0
        var nonNeutralCount = 0
        var neutralFalsePositives = 0

        for example in gold {
            let predicted = predictedByID[example.id] ?? .neutral
            confusion[example.label, default: [:]][predicted, default: 0] += 1
            if predicted == example.label {
                correct += 1
            }
            if example.label != .neutral {
                nonNeutralCount += 1
                if predicted == .neutral {
                    neutralFalsePositives += 1
                }
            }
        }

        var perLabel: [SentimentLabel: SentimentLabelMetrics] = [:]
        var macroF1Total = 0.0
        for label in SentimentLabel.allCases {
            let truePositive = Double(confusion[label]?[label] ?? 0)
            let falsePositive = Double(
                SentimentLabel.allCases
                    .filter { $0 != label }
                    .reduce(0) { $0 + (confusion[$1]?[label] ?? 0) }
            )
            let falseNegative = Double(
                SentimentLabel.allCases
                    .filter { $0 != label }
                    .reduce(0) { $0 + (confusion[label]?[$1] ?? 0) }
            )
            let precision = truePositive == 0 && falsePositive == 0 ? 0 : truePositive / max(truePositive + falsePositive, 1)
            let recall = truePositive == 0 && falseNegative == 0 ? 0 : truePositive / max(truePositive + falseNegative, 1)
            let f1: Double
            if precision + recall == 0 {
                f1 = 0
            } else {
                f1 = (2 * precision * recall) / (precision + recall)
            }
            perLabel[label] = SentimentLabelMetrics(
                precision: precision,
                recall: recall,
                f1: f1
            )
            macroF1Total += f1
        }

        return SentimentBenchmarkReport(
            exampleCount: gold.count,
            accuracy: gold.isEmpty ? 0 : Double(correct) / Double(gold.count),
            macroF1: macroF1Total / Double(SentimentLabel.allCases.count),
            neutralFalsePositiveRate: nonNeutralCount == 0 ? 0 : Double(neutralFalsePositives) / Double(nonNeutralCount),
            confusion: confusion,
            perLabel: perLabel
        )
    }
}
