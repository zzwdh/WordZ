import CoreML
import Foundation
import WordZAnalysis

enum SentimentModelError: Error {
    case invalidModelManifest
    case modelUnavailable
    case invalidModelInterface
}

private struct SentimentModelManifest: Decodable {
    let revision: String
    let providers: [SentimentModelProviderManifest]
}

private struct SentimentModelProviderManifest: Decodable {
    let id: String
    let type: String
    let revision: String?
    let modelResource: String?
    let fileExtension: String?
}

enum SentimentModelInputKind {
    case text(featureName: String)
    case denseFeatures(featureNames: [String])

    var primaryFeatureName: String {
        switch self {
        case .text(let featureName):
            return featureName
        case .denseFeatures(let featureNames):
            return featureNames.first ?? ""
        }
    }
}

struct SentimentLoadedModel {
    let model: MLModel
    let inputKind: SentimentModelInputKind
    let providerID: String
    let providerRevision: String
    let resourceRevision: String
    let predictedProbabilitiesName: String?
    let predictedFeatureName: String?
    let labelOutputName: String?
    let scalarOutputNames: [SentimentLabel: String]

    var inputFeatureName: String {
        inputKind.primaryFeatureName
    }
}

final class SentimentModelManager: @unchecked Sendable {
    private let bundle: Bundle
    private let manifestProvider: () -> Data?
    private let modelLoader: (URL) throws -> MLModel
    private let cacheLock = NSLock()
    private var cachedModel: SentimentLoadedModel?

    init(
        bundle: Bundle = WordZAnalysisResources.bundle,
        manifestProvider: (() -> Data?)? = nil,
        modelLoader: ((URL) throws -> MLModel)? = nil
    ) {
        self.bundle = bundle
        self.manifestProvider = manifestProvider ?? {
            guard let url = bundle.url(
                forResource: "SentimentModelManifest",
                withExtension: "json",
                subdirectory: "Sentiment"
            ) else {
                return nil
            }
            return try? Data(contentsOf: url)
        }
        self.modelLoader = modelLoader ?? { url in
            try MLModel(contentsOf: url)
        }
    }

    var isModelAvailable: Bool {
        (try? loadModel()) != nil
    }

    func loadModel() throws -> SentimentLoadedModel {
        if let cachedModel = withCachedModel({ $0 }) {
            return cachedModel
        }

        guard let manifestData = manifestProvider() else {
            throw SentimentModelError.modelUnavailable
        }

        let manifest: SentimentModelManifest
        do {
            manifest = try JSONDecoder().decode(SentimentModelManifest.self, from: manifestData)
        } catch {
            throw SentimentModelError.invalidModelManifest
        }

        for provider in manifest.providers where provider.type == "bundled-coreml" {
            guard let resourceName = provider.modelResource else { continue }
            let fileExtension = provider.fileExtension ?? "mlmodelc"
            guard let modelURL = bundle.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: "Sentiment"
            ) else {
                continue
            }

            let model = try modelLoader(modelURL)
            let inputFeatureName = model.modelDescription.inputDescriptionsByName.first {
                $0.value.type == .string
            }?.key
            let denseFeatureNames = denseFeatureNames(
                from: model.modelDescription.inputDescriptionsByName
            )
            let inputKind: SentimentModelInputKind?
            if let inputFeatureName {
                inputKind = .text(featureName: inputFeatureName)
            } else if !denseFeatureNames.isEmpty {
                inputKind = .denseFeatures(featureNames: denseFeatureNames)
            } else {
                inputKind = nil
            }

            guard let inputKind else {
                throw SentimentModelError.invalidModelInterface
            }

            let outputNames = model.modelDescription.outputDescriptionsByName
            let scalarOutputNames = scalarOutputNameMap(from: outputNames)
            let labelOutputName = model.modelDescription.predictedFeatureName ?? outputNames.first {
                $0.value.type == .string
            }?.key

            if model.modelDescription.predictedProbabilitiesName == nil,
               scalarOutputNames.count != SentimentLabel.allCases.count,
               labelOutputName == nil {
                throw SentimentModelError.invalidModelInterface
            }

            let loadedModel = SentimentLoadedModel(
                model: model,
                inputKind: inputKind,
                providerID: provider.id,
                providerRevision: provider.revision ?? provider.id,
                resourceRevision: manifest.revision,
                predictedProbabilitiesName: model.modelDescription.predictedProbabilitiesName,
                predictedFeatureName: model.modelDescription.predictedFeatureName,
                labelOutputName: labelOutputName,
                scalarOutputNames: scalarOutputNames
            )
            withCachedModel { cached in
                cached = loadedModel
            }
            return loadedModel
        }

        throw SentimentModelError.modelUnavailable
    }

    private func withCachedModel<T>(
        _ operation: (inout SentimentLoadedModel?) -> T
    ) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return operation(&cachedModel)
    }

    private func scalarOutputNameMap(
        from outputs: [String: MLFeatureDescription]
    ) -> [SentimentLabel: String] {
        var result: [SentimentLabel: String] = [:]
        for label in SentimentLabel.allCases {
            guard let outputName = candidateOutputNames(for: label).first(where: { name in
                guard let feature = outputs[name] else { return false }
                return feature.type == .double || feature.type == .int64
            }) else {
                continue
            }
            result[label] = outputName
        }
        return result
    }

    private func candidateOutputNames(for label: SentimentLabel) -> [String] {
        switch label {
        case .positive:
            return ["positive", "positivity", "pos"]
        case .neutral:
            return ["neutral", "neutrality", "neu"]
        case .negative:
            return ["negative", "negativity", "neg"]
        }
    }

    private func denseFeatureNames(
        from inputs: [String: MLFeatureDescription]
    ) -> [String] {
        inputs.compactMap { name, description in
            guard description.type == .double || description.type == .int64 else {
                return nil
            }
            return name
        }
        .sorted(by: naturalFeatureOrder)
    }

    private func naturalFeatureOrder(_ lhs: String, _ rhs: String) -> Bool {
        let lhsNumber = trailingInteger(in: lhs)
        let rhsNumber = trailingInteger(in: rhs)
        switch (lhsNumber, rhsNumber) {
        case let (.some(a), .some(b)) where a != b:
            return a < b
        default:
            return lhs < rhs
        }
    }

    private func trailingInteger(in value: String) -> Int? {
        let suffix = value.reversed().prefix { $0.isNumber }.reversed()
        guard !suffix.isEmpty else { return nil }
        return Int(String(suffix))
    }
}
