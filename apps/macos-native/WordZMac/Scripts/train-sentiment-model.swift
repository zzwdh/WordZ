#!/usr/bin/env swift

import CreateML
import CoreML
import Foundation
import NaturalLanguage

enum ScriptError: LocalizedError {
    case missingArgument(String)
    case invalidDataset
    case sentenceEmbeddingUnavailable
    case invalidModelInterface

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidDataset:
            return "The sentiment gold dataset is empty or malformed."
        case .sentenceEmbeddingUnavailable:
            return "English sentence embedding is unavailable on this machine."
        case .invalidModelInterface:
            return "The generated model interface is incompatible with the sentiment export pipeline."
        }
    }
}

struct GoldExample: Decodable {
    let id: String
    let split: String
    let domain: String
    let label: String
    let text: String
    let tags: [String]?
}

enum TrainingAlgorithm: String {
    case textMaxEnt = "text-maxent"
    case embeddingLogReg = "embedding-logreg"

    var providerFamily: String {
        switch self {
        case .textMaxEnt:
            return "textMaxEnt"
        case .embeddingLogReg:
            return "embeddingLogReg"
        }
    }

    var inputSchemaKind: String {
        switch self {
        case .textMaxEnt:
            return "text"
        case .embeddingLogReg:
            return "denseFeatures"
        }
    }
}

struct CLIOptions {
    let datasetPath: String
    let outputPath: String
    let version: String
    let algorithm: TrainingAlgorithm
    let datasetProfile: String
    let evaluationTarget: String
    let manifestOutputPath: String?
    let evaluationOutputPath: String?
    let providerID: String
    let modelResource: String
    let confidenceFloor: Double
    let marginFloor: Double
    let maxCharactersPerUnit: Int
}

private struct EvaluationLabelMetrics: Encodable {
    let precision: Double
    let recall: Double
    let f1: Double
}

private struct DomainEvaluationSummary: Encodable {
    let domain: String
    let exampleCount: Int
    let accuracy: Double
}

private struct SentimentModelEvaluationReport: Encodable {
    let version: String
    let algorithm: String
    let dataset: String
    let datasetProfile: String
    let evaluationTarget: String
    let providerID: String
    let modelResource: String
    let trainCount: Int
    let validationCount: Int
    let testCount: Int
    let accuracy: Double
    let macroF1: Double
    let confusion: [String: [String: Int]]
    let perLabel: [String: EvaluationLabelMetrics]
    let perDomain: [DomainEvaluationSummary]
}

private struct ExportedSentimentModelManifest: Encodable {
    let revision: String
    let defaultProviderID: String
    let language: String
    let labels: [String]
    let confidenceFloor: Double
    let marginFloor: Double
    let maxCharactersPerUnit: Int
    let supportsSentenceLevelAggregation: Bool
    let providers: [ExportedSentimentModelProvider]
}

private struct ExportedSentimentModelProvider: Encodable {
    let id: String
    let type: String
    let revision: String
    let modelResource: String
    let fileExtension: String
    let providerFamily: String
    let inputSchema: ExportedSentimentInputSchema
    let labelMap: [String: String]
    let sizeHintMB: Double
    let confidenceFloor: Double
    let marginFloor: Double
    let maxCharactersPerUnit: Int
    let supportsSentenceLevelAggregation: Bool
}

private struct ExportedSentimentInputSchema: Encodable {
    let kind: String
    let textFeatureName: String?
    let denseFeatureNames: [String]?
    let inputIDsFeatureName: String?
    let attentionMaskFeatureName: String?
    let tokenTypeIDsFeatureName: String?
    let maxSequenceLength: Int?
}

enum TrainSentimentModelScript {
    static func run() throws {
        let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        let datasetURL = URL(fileURLWithPath: options.datasetPath)
        let outputURL = URL(fileURLWithPath: options.outputPath)

        let data = try Data(contentsOf: datasetURL)
        let examples = try JSONDecoder().decode([GoldExample].self, from: data)
        guard !examples.isEmpty else {
            throw ScriptError.invalidDataset
        }

        let trainingExamples = examples.filter { $0.split == "train" }
        let validationExamples = examples.filter { $0.split == "validation" }
        let testExamples = examples.filter { $0.split == "test" }

        let metadata = MLModelMetadata(
            author: "OpenAI Codex",
            shortDescription: "English sentiment tri-classifier for WordZMac (neutral, positive, negative).",
            license: "Internal WordZMac development asset",
            version: options.version,
            additional: [
                "dataset": datasetURL.lastPathComponent,
                "algorithm": options.algorithm.rawValue,
                "trainCount": String(trainingExamples.count),
                "validationCount": String(validationExamples.count),
                "testCount": String(testExamples.count),
                "datasetProfile": options.datasetProfile,
                "evaluationTarget": options.evaluationTarget,
                "providerID": options.providerID,
                "modelResource": options.modelResource
            ]
        )

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        switch options.algorithm {
        case .textMaxEnt:
            try trainTextMaxEnt(
                trainingExamples: trainingExamples,
                validationExamples: validationExamples,
                testExamples: testExamples,
                outputURL: outputURL,
                metadata: metadata
            )
        case .embeddingLogReg:
            try trainEmbeddingLogisticRegression(
                trainingExamples: trainingExamples,
                validationExamples: validationExamples,
                testExamples: testExamples,
                outputURL: outputURL,
                metadata: metadata
            )
        }

        let loadableModelURL: URL?
        if options.evaluationOutputPath != nil || options.manifestOutputPath != nil {
            loadableModelURL = try compiledModelURL(for: outputURL)
        } else {
            loadableModelURL = nil
        }

        if let evaluationOutputPath = options.evaluationOutputPath {
            let evaluation = try makeEvaluationReport(
                modelURL: try requiredLoadableModelURL(loadableModelURL),
                testExamples: testExamples,
                datasetName: datasetURL.lastPathComponent,
                trainCount: trainingExamples.count,
                validationCount: validationExamples.count,
                options: options
            )
            try writeJSON(evaluation, to: URL(fileURLWithPath: evaluationOutputPath))
            print("Wrote evaluation report to \(evaluationOutputPath)")
        }

        if let manifestOutputPath = options.manifestOutputPath {
            let manifest = try makeManifest(
                modelURL: try requiredLoadableModelURL(loadableModelURL),
                options: options
            )
            try writeJSON(manifest, to: URL(fileURLWithPath: manifestOutputPath))
            print("Wrote model manifest to \(manifestOutputPath)")
        }
    }

    private static func trainTextMaxEnt(
        trainingExamples: [GoldExample],
        validationExamples: [GoldExample],
        testExamples: [GoldExample],
        outputURL: URL,
        metadata: MLModelMetadata
    ) throws {
        let trainingDictionary = groupedTexts(from: trainingExamples)
        let validationDictionary = groupedTexts(from: validationExamples)
        let testingDictionary = groupedTexts(from: testExamples)

        let parameters = MLTextClassifier.ModelParameters(
            validation: validationDictionary.isEmpty
                ? .split(strategy: .automatic)
                : .dictionary(validationDictionary),
            algorithm: .maxEnt(revision: 1),
            language: .english
        )

        let classifier = try MLTextClassifier(
            trainingData: trainingDictionary,
            parameters: parameters
        )

        let evaluation = classifier.evaluation(on: testingDictionary)
        let confidenceSample = try classifier.predictionWithConfidence(from: "The workflow is reliable and helpful.")
        print("Training complete using \(TrainingAlgorithm.textMaxEnt.rawValue).")
        print("Validation classification error: \(classifier.validationMetrics.classificationError)")
        print("Test classification error: \(evaluation.classificationError)")
        print("Sample confidence keys: \(confidenceSample.keys.sorted())")

        try classifier.write(to: outputURL, metadata: metadata)
        print("Wrote model source to \(outputURL.path)")
    }

    private static func trainEmbeddingLogisticRegression(
        trainingExamples: [GoldExample],
        validationExamples: [GoldExample],
        testExamples: [GoldExample],
        outputURL: URL,
        metadata: MLModelMetadata
    ) throws {
        guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
            throw ScriptError.sentenceEmbeddingUnavailable
        }

        let trainingTable = try embeddingTable(
            from: trainingExamples,
            sentenceEmbedding: sentenceEmbedding
        )
        let validationTable = try embeddingTable(
            from: validationExamples,
            sentenceEmbedding: sentenceEmbedding
        )
        let testTable = try embeddingTable(
            from: testExamples,
            sentenceEmbedding: sentenceEmbedding
        )
        let featureColumns = trainingTable.columnNames.filter { $0 != "label" }
        let parameters = MLLogisticRegressionClassifier.ModelParameters(
            validation: validationExamples.isEmpty ? .none : .table(validationTable),
            maxIterations: 60,
            l2Penalty: 0.01,
            featureRescaling: true
        )

        let classifier = try MLLogisticRegressionClassifier(
            trainingData: trainingTable,
            targetColumn: "label",
            featureColumns: featureColumns,
            parameters: parameters
        )
        let evaluation = classifier.evaluation(on: testTable)
        print("Training complete using \(TrainingAlgorithm.embeddingLogReg.rawValue).")
        print("Validation classification error: \(classifier.validationMetrics.classificationError)")
        print("Test classification error: \(evaluation.classificationError)")
        print("Feature count: \(featureColumns.count)")

        try classifier.write(to: outputURL, metadata: metadata)
        print("Wrote model source to \(outputURL.path)")
    }

    private static func embeddingTable(
        from examples: [GoldExample],
        sentenceEmbedding: NLEmbedding
    ) throws -> MLDataTable {
        guard !examples.isEmpty else { return MLDataTable() }

        let vectors = examples.map { example in
            vectorize(example.text, sentenceEmbedding: sentenceEmbedding)
        }
        guard let firstVector = vectors.first else {
            throw ScriptError.invalidDataset
        }

        var table = MLDataTable()
        table.addColumn(MLDataColumn(examples.map(\.label)), named: "label")
        for index in 0..<firstVector.count {
            let featureName = String(format: "f%03d", index)
            table.addColumn(MLDataColumn(vectors.map { $0[index] }), named: featureName)
        }
        return table
    }

    private static func vectorize(
        _ text: String,
        sentenceEmbedding: NLEmbedding
    ) -> [Double] {
        guard let vector = sentenceEmbedding.vector(for: text) else {
            return Array(repeating: 0, count: 512)
        }
        return vector.map { Double($0) }
    }

    private static func groupedTexts(from examples: [GoldExample]) -> [String: [String]] {
        Dictionary(grouping: examples, by: \.label)
            .mapValues { $0.map(\.text) }
    }

    private static func makeEvaluationReport(
        modelURL: URL,
        testExamples: [GoldExample],
        datasetName: String,
        trainCount: Int,
        validationCount: Int,
        options: CLIOptions
    ) throws -> SentimentModelEvaluationReport {
        let model = try MLModel(contentsOf: modelURL)
        let predictedByID = try Dictionary(uniqueKeysWithValues: testExamples.map { example in
            (
                example.id,
                try predictLabel(
                    for: example.text,
                    model: model,
                    algorithm: options.algorithm
                )
            )
        })

        let confusion = makeConfusionMatrix(
            examples: testExamples,
            predictedByID: predictedByID
        )
        let perLabel = makePerLabelMetrics(confusion: confusion)
        let macroF1 = perLabel.values.reduce(0.0) { $0 + $1.f1 } / Double(max(perLabel.count, 1))
        let accuracy = testExamples.isEmpty
            ? 0
            : Double(testExamples.filter { predictedByID[$0.id] == $0.label }.count) / Double(testExamples.count)
        let perDomain = makePerDomainSummaries(
            examples: testExamples,
            predictedByID: predictedByID
        )

        return SentimentModelEvaluationReport(
            version: options.version,
            algorithm: options.algorithm.rawValue,
            dataset: datasetName,
            datasetProfile: options.datasetProfile,
            evaluationTarget: options.evaluationTarget,
            providerID: options.providerID,
            modelResource: options.modelResource,
            trainCount: trainCount,
            validationCount: validationCount,
            testCount: testExamples.count,
            accuracy: accuracy,
            macroF1: macroF1,
            confusion: confusion,
            perLabel: perLabel,
            perDomain: perDomain
        )
    }

    private static func makeManifest(
        modelURL: URL,
        options: CLIOptions
    ) throws -> ExportedSentimentModelManifest {
        let model = try MLModel(contentsOf: modelURL)
        let revisionSuffix = normalizedRevisionSuffix(from: options.version)
        let inputs = model.modelDescription.inputDescriptionsByName
        let inputSchema: ExportedSentimentInputSchema
        switch options.algorithm {
        case .textMaxEnt:
            let textFeatureName = inputs.first(where: { $0.value.type == .string })?.key
            inputSchema = ExportedSentimentInputSchema(
                kind: options.algorithm.inputSchemaKind,
                textFeatureName: textFeatureName,
                denseFeatureNames: nil,
                inputIDsFeatureName: nil,
                attentionMaskFeatureName: nil,
                tokenTypeIDsFeatureName: nil,
                maxSequenceLength: nil
            )
        case .embeddingLogReg:
            let denseFeatureNames = inputs.compactMap { name, description -> String? in
                guard description.type == .double || description.type == .int64 else {
                    return nil
                }
                return name
            }.sorted()
            inputSchema = ExportedSentimentInputSchema(
                kind: options.algorithm.inputSchemaKind,
                textFeatureName: nil,
                denseFeatureNames: denseFeatureNames,
                inputIDsFeatureName: nil,
                attentionMaskFeatureName: nil,
                tokenTypeIDsFeatureName: nil,
                maxSequenceLength: nil
            )
        }

        return ExportedSentimentModelManifest(
            revision: "sentiment-model-pack-v\(revisionSuffix)",
            defaultProviderID: options.providerID,
            language: "en",
            labels: ["positive", "neutral", "negative"],
            confidenceFloor: options.confidenceFloor,
            marginFloor: options.marginFloor,
            maxCharactersPerUnit: options.maxCharactersPerUnit,
            supportsSentenceLevelAggregation: true,
            providers: [
                ExportedSentimentModelProvider(
                    id: options.providerID,
                    type: "bundled-coreml",
                    revision: "coreml-sentiment-v\(revisionSuffix)",
                    modelResource: options.modelResource,
                    fileExtension: "mlmodelc",
                    providerFamily: options.algorithm.providerFamily,
                    inputSchema: inputSchema,
                    labelMap: [
                        "positive": "positive",
                        "neutral": "neutral",
                        "negative": "negative"
                    ],
                    sizeHintMB: 0.5,
                    confidenceFloor: options.confidenceFloor,
                    marginFloor: options.marginFloor,
                    maxCharactersPerUnit: options.maxCharactersPerUnit,
                    supportsSentenceLevelAggregation: true
                )
            ]
        )
    }

    private static func predictLabel(
        for text: String,
        model: MLModel,
        algorithm: TrainingAlgorithm
    ) throws -> String {
        let provider: MLFeatureProvider
        switch algorithm {
        case .textMaxEnt:
            guard let textFeatureName = model.modelDescription.inputDescriptionsByName.first(where: {
                $0.value.type == .string
            })?.key else {
                throw ScriptError.invalidModelInterface
            }
            provider = try MLDictionaryFeatureProvider(dictionary: [
                textFeatureName: text
            ])
        case .embeddingLogReg:
            guard let sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english) else {
                throw ScriptError.sentenceEmbeddingUnavailable
            }
            let featureNames = model.modelDescription.inputDescriptionsByName.compactMap { name, description -> String? in
                guard description.type == .double || description.type == .int64 else {
                    return nil
                }
                return name
            }.sorted()
            let vector = vectorize(text, sentenceEmbedding: sentenceEmbedding)
            let dictionary = Dictionary(uniqueKeysWithValues: featureNames.enumerated().map { index, featureName in
                let value = index < vector.count ? vector[index] : 0
                return (featureName, NSNumber(value: value))
            })
            provider = try MLDictionaryFeatureProvider(dictionary: dictionary)
        }

        let prediction = try model.prediction(from: provider)
        if let predictedFeatureName = model.modelDescription.predictedFeatureName,
           let label = prediction.featureValue(for: predictedFeatureName)?.stringValue {
            return normalizedLabel(label)
        }
        if let firstStringOutput = model.modelDescription.outputDescriptionsByName.first(where: {
            $0.value.type == .string
        })?.key,
           let label = prediction.featureValue(for: firstStringOutput)?.stringValue {
            return normalizedLabel(label)
        }
        throw ScriptError.invalidModelInterface
    }

    private static func normalizedLabel(_ raw: String) -> String {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("positive") || normalized == "pos" {
            return "positive"
        }
        if normalized.contains("negative") || normalized == "neg" {
            return "negative"
        }
        return "neutral"
    }

    private static func makeConfusionMatrix(
        examples: [GoldExample],
        predictedByID: [String: String]
    ) -> [String: [String: Int]] {
        let labels = ["positive", "neutral", "negative"]
        var confusion = Dictionary(uniqueKeysWithValues: labels.map { gold in
            (gold, Dictionary(uniqueKeysWithValues: labels.map { ($0, 0) }))
        })

        for example in examples {
            let predicted = predictedByID[example.id] ?? "neutral"
            confusion[example.label, default: [:]][predicted, default: 0] += 1
        }
        return confusion
    }

    private static func normalizedRevisionSuffix(from version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "1" }
        if let numeric = Double(trimmed),
           numeric.rounded(.towardZero) == numeric {
            return String(Int(numeric))
        }
        return trimmed
    }

    private static func compiledModelURL(for modelURL: URL) throws -> URL {
        if modelURL.pathExtension == "mlmodelc" {
            return modelURL
        }
        return try MLModel.compileModel(at: modelURL)
    }

    private static func requiredLoadableModelURL(_ url: URL?) throws -> URL {
        guard let url else {
            throw ScriptError.invalidModelInterface
        }
        return url
    }

    private static func makePerLabelMetrics(
        confusion: [String: [String: Int]]
    ) -> [String: EvaluationLabelMetrics] {
        let labels = ["positive", "neutral", "negative"]
        return Dictionary(uniqueKeysWithValues: labels.map { label in
            let truePositive = Double(confusion[label]?[label] ?? 0)
            let falsePositive = Double(labels.filter { $0 != label }.reduce(0) { partial, goldLabel in
                partial + (confusion[goldLabel]?[label] ?? 0)
            })
            let falseNegative = Double(labels.filter { $0 != label }.reduce(0) { partial, predictedLabel in
                partial + (confusion[label]?[predictedLabel] ?? 0)
            })
            let precision = truePositive == 0 && falsePositive == 0 ? 0 : truePositive / max(truePositive + falsePositive, 1)
            let recall = truePositive == 0 && falseNegative == 0 ? 0 : truePositive / max(truePositive + falseNegative, 1)
            let f1: Double
            if precision + recall == 0 {
                f1 = 0
            } else {
                f1 = (2 * precision * recall) / (precision + recall)
            }
            return (
                label,
                EvaluationLabelMetrics(
                    precision: precision,
                    recall: recall,
                    f1: f1
                )
            )
        })
    }

    private static func makePerDomainSummaries(
        examples: [GoldExample],
        predictedByID: [String: String]
    ) -> [DomainEvaluationSummary] {
        Dictionary(grouping: examples, by: \.domain)
            .map { domain, domainExamples in
                let correctCount = domainExamples.filter { predictedByID[$0.id] == $0.label }.count
                return DomainEvaluationSummary(
                    domain: domain,
                    exampleCount: domainExamples.count,
                    accuracy: domainExamples.isEmpty ? 0 : Double(correctCount) / Double(domainExamples.count)
                )
            }
            .sorted { $0.domain < $1.domain }
    }

    private static func writeJSON<T: Encodable>(
        _ value: T,
        to url: URL
    ) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    private static func parseOptions(arguments: [String]) throws -> CLIOptions {
        var datasetPath: String?
        var outputPath: String?
        var version = "1"
        var algorithm = TrainingAlgorithm.embeddingLogReg
        var datasetProfile = "custom"
        var evaluationTarget = "custom"
        var manifestOutputPath: String?
        var evaluationOutputPath: String?
        var providerID = "bundled-coreml-sentiment"
        var modelResource = "SentimentTriClassifier"
        var confidenceFloor = 0.55
        var marginFloor = 0.12
        var maxCharactersPerUnit = 1600

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--dataset":
                index += 1
                datasetPath = safeArgument(at: index, in: arguments)
            case "--output":
                index += 1
                outputPath = safeArgument(at: index, in: arguments)
            case "--version":
                index += 1
                version = safeArgument(at: index, in: arguments) ?? version
            case "--algorithm":
                index += 1
                if let rawValue = safeArgument(at: index, in: arguments),
                   let parsed = TrainingAlgorithm(rawValue: rawValue) {
                    algorithm = parsed
                }
            case "--dataset-profile":
                index += 1
                datasetProfile = safeArgument(at: index, in: arguments) ?? datasetProfile
            case "--evaluation-target":
                index += 1
                evaluationTarget = safeArgument(at: index, in: arguments) ?? evaluationTarget
            case "--manifest-out":
                index += 1
                manifestOutputPath = safeArgument(at: index, in: arguments)
            case "--evaluation-out":
                index += 1
                evaluationOutputPath = safeArgument(at: index, in: arguments)
            case "--provider-id":
                index += 1
                providerID = safeArgument(at: index, in: arguments) ?? providerID
            case "--model-resource":
                index += 1
                modelResource = safeArgument(at: index, in: arguments) ?? modelResource
            case "--confidence-floor":
                index += 1
                if let rawValue = safeArgument(at: index, in: arguments),
                   let parsed = Double(rawValue) {
                    confidenceFloor = parsed
                }
            case "--margin-floor":
                index += 1
                if let rawValue = safeArgument(at: index, in: arguments),
                   let parsed = Double(rawValue) {
                    marginFloor = parsed
                }
            case "--max-characters":
                index += 1
                if let rawValue = safeArgument(at: index, in: arguments),
                   let parsed = Int(rawValue) {
                    maxCharactersPerUnit = parsed
                }
            default:
                break
            }
            index += 1
        }

        guard let datasetPath else {
            throw ScriptError.missingArgument("--dataset")
        }
        guard let outputPath else {
            throw ScriptError.missingArgument("--output")
        }

        return CLIOptions(
            datasetPath: datasetPath,
            outputPath: outputPath,
            version: version,
            algorithm: algorithm,
            datasetProfile: datasetProfile,
            evaluationTarget: evaluationTarget,
            manifestOutputPath: manifestOutputPath,
            evaluationOutputPath: evaluationOutputPath,
            providerID: providerID,
            modelResource: modelResource,
            confidenceFloor: confidenceFloor,
            marginFloor: marginFloor,
            maxCharactersPerUnit: maxCharactersPerUnit
        )
    }

    private static func safeArgument(at index: Int, in arguments: [String]) -> String? {
        guard arguments.indices.contains(index) else { return nil }
        return arguments[index]
    }
}

do {
    try TrainSentimentModelScript.run()
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
