#!/usr/bin/env swift

import CreateML
import CoreML
import Foundation
import NaturalLanguage

enum ScriptError: LocalizedError {
    case missingArgument(String)
    case invalidDataset
    case sentenceEmbeddingUnavailable

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidDataset:
            return "The sentiment gold dataset is empty or malformed."
        case .sentenceEmbeddingUnavailable:
            return "English sentence embedding is unavailable on this machine."
        }
    }
}

struct GoldExample: Decodable {
    let id: String
    let split: String
    let domain: String
    let label: String
    let text: String
}

enum TrainingAlgorithm: String {
    case textMaxEnt = "text-maxent"
    case embeddingLogReg = "embedding-logreg"
}

struct CLIOptions {
    let datasetPath: String
    let outputPath: String
    let version: String
    let algorithm: TrainingAlgorithm
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
                "testCount": String(testExamples.count)
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

    private static func parseOptions(arguments: [String]) throws -> CLIOptions {
        var datasetPath: String?
        var outputPath: String?
        var version = "1.0"
        var algorithm = TrainingAlgorithm.embeddingLogReg

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
            algorithm: algorithm
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
