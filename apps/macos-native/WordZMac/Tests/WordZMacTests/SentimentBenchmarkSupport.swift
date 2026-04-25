import Foundation
@testable import WordZWorkspaceCore

enum SentimentGoldDatasetVersion: String, CaseIterable, Codable {
    case v1 = "sentiment-gold-v1"
    case v2 = "sentiment-gold-v2"
    case v3 = "sentiment-gold-v3"
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
    let tags: [String]

    private enum CodingKeys: String, CodingKey {
        case id
        case split
        case domain
        case label
        case text
        case tags
    }

    init(
        id: String,
        split: SentimentGoldSplit,
        domain: String,
        label: SentimentLabel,
        text: String,
        tags: [String] = []
    ) {
        self.id = id
        self.split = split
        self.domain = domain
        self.label = label
        self.text = text
        self.tags = tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.split = try container.decode(SentimentGoldSplit.self, forKey: .split)
        self.domain = try container.decode(String.self, forKey: .domain)
        self.label = try container.decode(SentimentLabel.self, forKey: .label)
        self.text = try container.decode(String.self, forKey: .text)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

struct SentimentLabelMetrics: Codable {
    let precision: Double
    let recall: Double
    let f1: Double
}

struct SentimentBenchmarkSliceReport: Codable {
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

struct SentimentBenchmarkReport: Codable {
    let exampleCount: Int
    let accuracy: Double
    let macroF1: Double
    let neutralFalsePositiveRate: Double
    let confusion: [SentimentLabel: [SentimentLabel: Int]]
    let perLabel: [SentimentLabel: SentimentLabelMetrics]
    let perDomain: [String: SentimentBenchmarkSliceReport]
    let slices: [String: SentimentBenchmarkSliceReport]

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

enum SentimentBenchmarkProfile: String, CaseIterable, Codable {
    case mixedBaseline = "mixed-baseline"
    case newsFocused = "news-focused"

    var datasetVersion: SentimentGoldDatasetVersion {
        switch self {
        case .mixedBaseline:
            return .v2
        case .newsFocused:
            return .v3
        }
    }

    var title: String {
        switch self {
        case .mixedBaseline:
            return "Mixed Baseline"
        case .newsFocused:
            return "News Focused"
        }
    }

    var requiredSliceKeys: [String] {
        switch self {
        case .mixedBaseline:
            return []
        case .newsFocused:
            return ["quoted", "reported", "procedural", "commentary", "stance"]
        }
    }
}

struct SentimentBenchmarkSavedBaseline: Codable {
    let datasetVersion: SentimentGoldDatasetVersion
    let exampleCount: Int
    let accuracy: Double
    let macroF1: Double
    let neutralFalsePositiveRate: Double
    let requiredSliceKeys: [String]
}

struct SentimentBenchmarkDelta: Codable {
    let accuracyDelta: Double
    let macroF1Delta: Double
    let neutralFalsePositiveRateDelta: Double
}

struct SentimentBenchmarkProfileExecution {
    let profile: SentimentBenchmarkProfile
    let datasetVersion: SentimentGoldDatasetVersion
    let report: SentimentBenchmarkReport
    let savedBaseline: SentimentBenchmarkSavedBaseline?
    let savedBaselineDelta: SentimentBenchmarkDelta?
    let legacyBaseline: SentimentBenchmarkReport?
    let legacyBaselineDelta: SentimentBenchmarkDelta?
}

struct SentimentBenchmarkProfileSnapshot: Codable {
    let profile: SentimentBenchmarkProfile
    let title: String
    let datasetVersion: SentimentGoldDatasetVersion
    let report: SentimentBenchmarkReport
    let savedBaseline: SentimentBenchmarkSavedBaseline?
    let savedBaselineDelta: SentimentBenchmarkDelta?
    let legacyBaseline: SentimentBenchmarkReport?
    let legacyBaselineDelta: SentimentBenchmarkDelta?
}

struct SentimentBenchmarkSnapshotBundle: Codable {
    let generatedAt: String
    let profiles: [SentimentBenchmarkProfileSnapshot]
}

enum SentimentBenchmarkPackStrategy {
    case legacyMixed
    case domainAware
}

struct SentimentBenchmarkLexiconTuning {
    let thresholds: SentimentThresholds
    let newsBiasAdjustment: Double
    let quoteDiscountMultiplier: Double
    let reportingDiscountMultiplier: Double

    var domainBiasAdjustments: [String: Double] {
        abs(newsBiasAdjustment) < 0.0001 ? [:] : [SentimentDomainPackID.news.rawValue: newsBiasAdjustment]
    }

    static func packAware(thresholds: SentimentThresholds) -> Self {
        SentimentBenchmarkLexiconTuning(
            thresholds: thresholds,
            newsBiasAdjustment: 0.05,
            quoteDiscountMultiplier: 0.85,
            reportingDiscountMultiplier: 0.9
        )
    }

    static func legacyNewsBaseline(thresholds: SentimentThresholds) -> Self {
        SentimentBenchmarkLexiconTuning(
            thresholds: thresholds,
            newsBiasAdjustment: 0.0,
            quoteDiscountMultiplier: 0.85,
            reportingDiscountMultiplier: 1.0
        )
    }
}

struct SentimentCalibrationResult {
    let tuning: SentimentBenchmarkLexiconTuning
    let report: SentimentBenchmarkReport

    var thresholds: SentimentThresholds { tuning.thresholds }
}

enum SentimentGoldDataset {
    static func load(
        version: SentimentGoldDatasetVersion,
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

enum SentimentBenchmarkBaselineStore {
    private static let baselineResourceName = "sentiment-benchmark-baselines"

    static func load(
        filePath: StaticString = #filePath
    ) throws -> [SentimentBenchmarkProfile: SentimentBenchmarkSavedBaseline] {
        let baselineURL = Bundle.module.url(
            forResource: baselineResourceName,
            withExtension: "json",
            subdirectory: "Fixtures/Sentiment"
        ) ?? URL(fileURLWithPath: "\(filePath)")
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures", isDirectory: true)
            .appendingPathComponent("Sentiment", isDirectory: true)
            .appendingPathComponent("\(baselineResourceName).json")
        let data = try Data(contentsOf: baselineURL)
        let rawBaselines = try JSONDecoder().decode([String: SentimentBenchmarkSavedBaseline].self, from: data)
        return Dictionary(
            uniqueKeysWithValues: rawBaselines.compactMap { rawKey, value in
                guard let profile = SentimentBenchmarkProfile(rawValue: rawKey) else { return nil }
                return (profile, value)
            }
        )
    }
}

enum SentimentBenchmarkHarness {
    private static let trackedSlices = ["quoted", "reported", "procedural", "commentary", "stance"]

    static func evaluate(
        examples: [SentimentGoldExample],
        thresholds: SentimentThresholds,
        backend: SentimentBackendKind,
        packStrategy: SentimentBenchmarkPackStrategy = .domainAware,
        lexiconTuning: SentimentBenchmarkLexiconTuning? = nil,
        engine: NativeAnalysisEngine = NativeAnalysisEngine()
    ) -> SentimentBenchmarkReport {
        let predictedByID = evaluatePredictions(
            examples: examples,
            thresholds: thresholds,
            backend: backend,
            packStrategy: packStrategy,
            lexiconTuning: lexiconTuning ?? .packAware(thresholds: thresholds),
            engine: engine
        )
        return makeReport(
            gold: examples,
            predictedByID: predictedByID
        )
    }

    static func calibrateLexicon(
        validationExamples: [SentimentGoldExample],
        packStrategy: SentimentBenchmarkPackStrategy = .domainAware,
        decisionThresholds: [Double] = [0.2, 0.25, 0.3],
        minimumEvidenceValues: [Double] = [0.6, 0.8, 1.0],
        neutralBiasValues: [Double] = [0.9, 1.0, 1.1],
        newsBiasValues: [Double] = [0.0, 0.05, 0.1],
        quoteDiscountValues: [Double] = [0.8, 0.85, 0.9],
        reportingDiscountValues: [Double] = [0.85, 0.9, 1.0]
    ) -> SentimentCalibrationResult {
        precondition(!validationExamples.isEmpty, "Validation examples must not be empty.")

        var best: SentimentCalibrationResult?
        for decisionThreshold in decisionThresholds {
            for minimumEvidence in minimumEvidenceValues {
                for neutralBias in neutralBiasValues {
                    for newsBias in newsBiasValues {
                        for quoteDiscount in quoteDiscountValues {
                            for reportingDiscount in reportingDiscountValues {
                                let tuning = SentimentBenchmarkLexiconTuning(
                                    thresholds: SentimentThresholds(
                                        decisionThreshold: decisionThreshold,
                                        minimumEvidence: minimumEvidence,
                                        neutralBias: neutralBias
                                    ),
                                    newsBiasAdjustment: newsBias,
                                    quoteDiscountMultiplier: quoteDiscount,
                                    reportingDiscountMultiplier: reportingDiscount
                                )
                                let report = evaluate(
                                    examples: validationExamples,
                                    thresholds: tuning.thresholds,
                                    backend: .lexicon,
                                    packStrategy: packStrategy,
                                    lexiconTuning: tuning
                                )
                                let candidate = SentimentCalibrationResult(
                                    tuning: tuning,
                                    report: report
                                )
                                if isBetter(candidate: candidate, than: best) {
                                    best = candidate
                                }
                            }
                        }
                    }
                }
            }
        }

        return best!
    }

    private static func evaluatePredictions(
        examples: [SentimentGoldExample],
        thresholds: SentimentThresholds,
        backend: SentimentBackendKind,
        packStrategy: SentimentBenchmarkPackStrategy,
        lexiconTuning: SentimentBenchmarkLexiconTuning,
        engine: NativeAnalysisEngine
    ) -> [String: SentimentLabel] {
        let groupedExamples = Dictionary(grouping: examples) { example in
            benchmarkRequestPackID(for: example, strategy: packStrategy)
        }

        var predictedByID: [String: SentimentLabel] = [:]
        for (packID, groupedRows) in groupedExamples {
            let request = SentimentRunRequest(
                source: .pastedText,
                unit: .document,
                contextBasis: .visibleContext,
                thresholds: thresholds,
                texts: groupedRows.map {
                    SentimentInputText(
                        id: $0.id,
                        sourceTitle: $0.domain,
                        text: $0.text
                    )
                },
                backend: backend,
                domainPackID: packID,
                ruleProfile: benchmarkRuleProfile(
                    selectedPackID: packID,
                    tuning: lexiconTuning
                ),
                calibrationProfile: benchmarkCalibrationProfile(
                    selectedPackID: packID,
                    tuning: lexiconTuning
                )
            )
            let result = engine.runSentiment(request)
            result.rows.forEach { predictedByID[$0.id] = $0.finalLabel }
        }

        return predictedByID
    }

    private static func benchmarkRuleProfile(
        selectedPackID: SentimentDomainPackID,
        tuning: SentimentBenchmarkLexiconTuning
    ) -> SentimentRuleProfile {
        SentimentRuleProfile(
            id: "benchmark",
            title: "Benchmark",
            sourceKind: .workspace,
            preferredPackID: selectedPackID,
            thresholdPreset: .custom,
            neutralShieldStrength: 0.7,
            quoteDiscountEnabled: true,
            quoteDiscountMultiplier: tuning.quoteDiscountMultiplier,
            reportingDiscountMultiplier: tuning.reportingDiscountMultiplier,
            revision: "benchmark-rule-v3"
        )
    }

    private static func benchmarkCalibrationProfile(
        selectedPackID: SentimentDomainPackID,
        tuning: SentimentBenchmarkLexiconTuning
    ) -> SentimentCalibrationProfile {
        SentimentCalibrationProfile(
            id: "benchmark",
            decisionThreshold: tuning.thresholds.decisionThreshold,
            minimumEvidence: tuning.thresholds.minimumEvidence,
            neutralBias: tuning.thresholds.neutralBias,
            domainBiasAdjustments: tuning.domainBiasAdjustments,
            preferredPackIDs: [selectedPackID],
            revision: "benchmark-calibration-v3"
        )
    }

    private static func benchmarkRequestPackID(
        for example: SentimentGoldExample,
        strategy: SentimentBenchmarkPackStrategy
    ) -> SentimentDomainPackID {
        switch strategy {
        case .legacyMixed:
            return .mixed
        case .domainAware:
            switch example.domain.localizedLowercase {
            case "general":
                return .general
            case "academic":
                return .academic
            case "news":
                return .news
            case "kwic":
                return .kwic
            default:
                return .mixed
            }
        }
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
        let overall = makeSliceReport(
            gold: gold,
            predictedByID: predictedByID
        )
        let perDomain = Dictionary(
            uniqueKeysWithValues: Set(gold.map(\.domain)).sorted().map { domain in
                let domainExamples = gold.filter { $0.domain == domain }
                return (
                    domain,
                    makeSliceReport(gold: domainExamples, predictedByID: predictedByID)
                )
            }
        )
        let slices: [String: SentimentBenchmarkSliceReport] = Dictionary(
            uniqueKeysWithValues: trackedSlices.compactMap { tag in
                let sliceExamples = gold.filter { $0.tags.contains(tag) }
                guard !sliceExamples.isEmpty else { return nil }
                return (
                    tag,
                    makeSliceReport(gold: sliceExamples, predictedByID: predictedByID)
                )
            }
        )

        return SentimentBenchmarkReport(
            exampleCount: overall.exampleCount,
            accuracy: overall.accuracy,
            macroF1: overall.macroF1,
            neutralFalsePositiveRate: overall.neutralFalsePositiveRate,
            confusion: overall.confusion,
            perLabel: overall.perLabel,
            perDomain: perDomain,
            slices: slices
        )
    }

    private static func makeSliceReport(
        gold: [SentimentGoldExample],
        predictedByID: [String: SentimentLabel]
    ) -> SentimentBenchmarkSliceReport {
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

        return SentimentBenchmarkSliceReport(
            exampleCount: gold.count,
            accuracy: gold.isEmpty ? 0 : Double(correct) / Double(gold.count),
            macroF1: macroF1Total / Double(SentimentLabel.allCases.count),
            neutralFalsePositiveRate: nonNeutralCount == 0 ? 0 : Double(neutralFalsePositives) / Double(nonNeutralCount),
            confusion: confusion,
            perLabel: perLabel
        )
    }
}

enum SentimentBenchmarkReporter {
    static func execute(
        profile: SentimentBenchmarkProfile,
        savedBaselines: [SentimentBenchmarkProfile: SentimentBenchmarkSavedBaseline] = [:],
        engine: NativeAnalysisEngine = NativeAnalysisEngine()
    ) throws -> SentimentBenchmarkProfileExecution {
        let savedBaseline = savedBaselines[profile]

        switch profile {
        case .mixedBaseline:
            let dataset = try SentimentGoldDataset.load(version: profile.datasetVersion)
            let testExamples = dataset.filter { $0.split == .test }
            let report = SentimentBenchmarkHarness.evaluate(
                examples: testExamples,
                thresholds: SentimentThresholdPreset.conservative.thresholds,
                backend: .lexicon,
                engine: engine
            )
            return SentimentBenchmarkProfileExecution(
                profile: profile,
                datasetVersion: profile.datasetVersion,
                report: report,
                savedBaseline: savedBaseline,
                savedBaselineDelta: savedBaseline.map { delta(from: $0, to: report) },
                legacyBaseline: nil,
                legacyBaselineDelta: nil
            )
        case .newsFocused:
            let dataset = try SentimentGoldDataset.load(version: profile.datasetVersion)
            let validationExamples = dataset.filter { $0.split == .validation }
            let testExamples = dataset.filter { $0.split == .test }
            let legacyTuning = SentimentBenchmarkLexiconTuning.legacyNewsBaseline(
                thresholds: SentimentThresholdPreset.balanced.thresholds
            )
            let legacyBaseline = SentimentBenchmarkHarness.evaluate(
                examples: testExamples,
                thresholds: legacyTuning.thresholds,
                backend: .lexicon,
                packStrategy: .legacyMixed,
                lexiconTuning: legacyTuning,
                engine: engine
            )
            let calibrated = SentimentBenchmarkHarness.calibrateLexicon(
                validationExamples: validationExamples,
                packStrategy: .domainAware
            )
            let report = SentimentBenchmarkHarness.evaluate(
                examples: testExamples,
                thresholds: calibrated.thresholds,
                backend: .lexicon,
                packStrategy: .domainAware,
                lexiconTuning: calibrated.tuning,
                engine: engine
            )
            return SentimentBenchmarkProfileExecution(
                profile: profile,
                datasetVersion: profile.datasetVersion,
                report: report,
                savedBaseline: savedBaseline,
                savedBaselineDelta: savedBaseline.map { delta(from: $0, to: report) },
                legacyBaseline: legacyBaseline,
                legacyBaselineDelta: delta(from: legacyBaseline, to: report)
            )
        }
    }

    static func snapshot(
        for execution: SentimentBenchmarkProfileExecution
    ) -> SentimentBenchmarkProfileSnapshot {
        SentimentBenchmarkProfileSnapshot(
            profile: execution.profile,
            title: execution.profile.title,
            datasetVersion: execution.datasetVersion,
            report: execution.report,
            savedBaseline: execution.savedBaseline,
            savedBaselineDelta: execution.savedBaselineDelta,
            legacyBaseline: execution.legacyBaseline,
            legacyBaselineDelta: execution.legacyBaselineDelta
        )
    }

    static func writeSnapshots(
        _ snapshots: [SentimentBenchmarkProfileSnapshot],
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let formatter = ISO8601DateFormatter()
        let bundle = SentimentBenchmarkSnapshotBundle(
            generatedAt: formatter.string(from: Date()),
            profiles: snapshots
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    private static func delta(
        from baseline: SentimentBenchmarkSavedBaseline,
        to report: SentimentBenchmarkReport
    ) -> SentimentBenchmarkDelta {
        SentimentBenchmarkDelta(
            accuracyDelta: report.accuracy - baseline.accuracy,
            macroF1Delta: report.macroF1 - baseline.macroF1,
            neutralFalsePositiveRateDelta: report.neutralFalsePositiveRate - baseline.neutralFalsePositiveRate
        )
    }

    private static func delta(
        from baseline: SentimentBenchmarkReport,
        to report: SentimentBenchmarkReport
    ) -> SentimentBenchmarkDelta {
        SentimentBenchmarkDelta(
            accuracyDelta: report.accuracy - baseline.accuracy,
            macroF1Delta: report.macroF1 - baseline.macroF1,
            neutralFalsePositiveRateDelta: report.neutralFalsePositiveRate - baseline.neutralFalsePositiveRate
        )
    }
}
