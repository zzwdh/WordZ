import CoreML
import Foundation
import WordZAnalysis

enum SentimentModelError: Error {
    case invalidModelManifest
    case modelUnavailable
    case invalidModelInterface
}

enum SentimentModelAvailabilityReason: String, Codable, Sendable {
    case available
    case manifestMissing
    case invalidManifest
    case providerMissing
    case invalidInterface
    case loadFailed
}

struct SentimentModelAvailability: Equatable, Codable, Sendable {
    let isAvailable: Bool
    let reason: SentimentModelAvailabilityReason
    let defaultProviderID: String?
    let resourceRevision: String?
}

struct SentimentModelInputSchemaManifest: Decodable, Equatable, Sendable {
    let kind: SentimentModelInputSchemaKind
    let textFeatureName: String?
    let denseFeatureNames: [String]?
    let inputIDsFeatureName: String?
    let attentionMaskFeatureName: String?
    let tokenTypeIDsFeatureName: String?
    let maxSequenceLength: Int?

    init(
        kind: SentimentModelInputSchemaKind,
        textFeatureName: String? = nil,
        denseFeatureNames: [String]? = nil,
        inputIDsFeatureName: String? = nil,
        attentionMaskFeatureName: String? = nil,
        tokenTypeIDsFeatureName: String? = nil,
        maxSequenceLength: Int? = nil
    ) {
        self.kind = kind
        self.textFeatureName = textFeatureName
        self.denseFeatureNames = denseFeatureNames
        self.inputIDsFeatureName = inputIDsFeatureName
        self.attentionMaskFeatureName = attentionMaskFeatureName
        self.tokenTypeIDsFeatureName = tokenTypeIDsFeatureName
        self.maxSequenceLength = maxSequenceLength
    }
}

struct SentimentModelManifest: Decodable, Equatable, Sendable {
    let revision: String
    let defaultProviderID: String?
    let language: String?
    let labels: [String]
    let confidenceFloor: Double?
    let marginFloor: Double?
    let maxCharactersPerUnit: Int?
    let supportsSentenceLevelAggregation: Bool?
    let providers: [SentimentModelProviderManifest]

    init(
        revision: String,
        defaultProviderID: String? = nil,
        language: String? = nil,
        labels: [String] = SentimentLabel.allCases.map(\.rawValue),
        confidenceFloor: Double? = nil,
        marginFloor: Double? = nil,
        maxCharactersPerUnit: Int? = nil,
        supportsSentenceLevelAggregation: Bool? = nil,
        providers: [SentimentModelProviderManifest]
    ) {
        self.revision = revision
        self.defaultProviderID = defaultProviderID
        self.language = language
        self.labels = labels
        self.confidenceFloor = confidenceFloor
        self.marginFloor = marginFloor
        self.maxCharactersPerUnit = maxCharactersPerUnit
        self.supportsSentenceLevelAggregation = supportsSentenceLevelAggregation
        self.providers = providers
    }
}

struct SentimentModelProviderManifest: Decodable, Equatable, Sendable {
    let id: String
    let type: String
    let revision: String?
    let modelResource: String?
    let fileExtension: String?
    let providerFamily: SentimentModelProviderFamily?
    let inputSchema: SentimentModelInputSchemaManifest?
    let tokenizerResource: String?
    let labelMap: [String: String]?
    let sizeHintMB: Double?
    let confidenceFloor: Double?
    let marginFloor: Double?
    let maxCharactersPerUnit: Int?
    let supportsSentenceLevelAggregation: Bool?
}

enum SentimentModelInputKind {
    case text(featureName: String)
    case denseFeatures(featureNames: [String])
    case tokenizedText(
        inputIDsFeatureName: String,
        attentionMaskFeatureName: String,
        tokenTypeIDsFeatureName: String?,
        maxSequenceLength: Int
    )

    var primaryFeatureName: String {
        switch self {
        case .text(let featureName):
            return featureName
        case .denseFeatures(let featureNames):
            return featureNames.first ?? ""
        case .tokenizedText(let inputIDsFeatureName, _, _, _):
            return inputIDsFeatureName
        }
    }

    var schemaKind: SentimentModelInputSchemaKind {
        switch self {
        case .text:
            return .text
        case .denseFeatures:
            return .denseFeatures
        case .tokenizedText:
            return .tokenizedText
        }
    }
}

struct SentimentLoadedModel {
    let model: MLModel
    let inputKind: SentimentModelInputKind
    let providerID: String
    let providerRevision: String
    let providerFamily: SentimentModelProviderFamily
    let resourceRevision: String
    let predictedProbabilitiesName: String?
    let predictedFeatureName: String?
    let labelOutputName: String?
    let scalarOutputNames: [SentimentLabel: String]
    let labelAliases: [String: SentimentLabel]
    let defaultConfidenceFloor: Double
    let defaultMarginFloor: Double
    let maxCharactersPerUnit: Int
    let supportsSentenceLevelAggregation: Bool
    let sizeHintMB: Double?

    var inputFeatureName: String {
        inputKind.primaryFeatureName
    }

    var inputSchemaKind: SentimentModelInputSchemaKind {
        inputKind.schemaKind
    }
}

final class SentimentModelManager: @unchecked Sendable {
    private enum Constants {
        static let defaultConfidenceFloor = 0.55
        static let defaultMarginFloor = 0.12
        static let defaultMaxCharactersPerUnit = 1_600
        static let defaultTokenSequenceLength = 256
    }

    private let bundle: Bundle
    private let manifestProvider: () -> Data?
    private let modelLoader: (URL) throws -> MLModel
    private let cacheLock = NSLock()
    private var cachedManifest: SentimentModelManifest?
    private var cachedModels: [String: SentimentLoadedModel] = [:]

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
        availability().isAvailable
    }

    func availability() -> SentimentModelAvailability {
        do {
            let manifest = try loadManifest()
            let model = try loadModel()
            return SentimentModelAvailability(
                isAvailable: true,
                reason: .available,
                defaultProviderID: manifest.defaultProviderID ?? model.providerID,
                resourceRevision: manifest.revision
            )
        } catch SentimentModelError.modelUnavailable {
            let manifest = try? loadManifest()
            return SentimentModelAvailability(
                isAvailable: false,
                reason: manifest == nil ? .manifestMissing : .providerMissing,
                defaultProviderID: manifest?.defaultProviderID,
                resourceRevision: manifest?.revision
            )
        } catch SentimentModelError.invalidModelManifest {
            return SentimentModelAvailability(
                isAvailable: false,
                reason: .invalidManifest,
                defaultProviderID: nil,
                resourceRevision: nil
            )
        } catch SentimentModelError.invalidModelInterface {
            let manifest = try? loadManifest()
            return SentimentModelAvailability(
                isAvailable: false,
                reason: .invalidInterface,
                defaultProviderID: manifest?.defaultProviderID,
                resourceRevision: manifest?.revision
            )
        } catch {
            let manifest = try? loadManifest()
            return SentimentModelAvailability(
                isAvailable: false,
                reason: .loadFailed,
                defaultProviderID: manifest?.defaultProviderID,
                resourceRevision: manifest?.revision
            )
        }
    }

    func loadModel(providerID: String? = nil) throws -> SentimentLoadedModel {
        let manifest = try loadManifest()
        let providers = orderedProviders(in: manifest, preferredProviderID: providerID)
        guard !providers.isEmpty else {
            throw SentimentModelError.modelUnavailable
        }

        for provider in providers where provider.type == "bundled-coreml" {
            if let cached = withCachedModels({ $0[provider.id] }) {
                return cached
            }

            guard let resourceName = provider.modelResource else { continue }
            let fileExtension = provider.fileExtension ?? "mlmodelc"
            guard let modelURL = bundle.url(
                forResource: resourceName,
                withExtension: fileExtension,
                subdirectory: "Sentiment"
            ) else {
                continue
            }

            let loadedModel = try makeLoadedModel(
                manifest: manifest,
                provider: provider,
                modelURL: modelURL
            )
            withCachedModels { cachedModels in
                cachedModels[provider.id] = loadedModel
            }
            return loadedModel
        }

        throw SentimentModelError.modelUnavailable
    }

    private func loadManifest() throws -> SentimentModelManifest {
        if let cachedManifest = withCachedManifest({ $0 }) {
            return cachedManifest
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

        withCachedManifest { cachedManifest in
            cachedManifest = manifest
        }
        return manifest
    }

    private func orderedProviders(
        in manifest: SentimentModelManifest,
        preferredProviderID: String?
    ) -> [SentimentModelProviderManifest] {
        let preferredID = preferredProviderID ?? manifest.defaultProviderID
        guard let preferredID else { return manifest.providers }

        return manifest.providers.sorted { lhs, rhs in
            switch (lhs.id == preferredID, rhs.id == preferredID) {
            case (true, false):
                return true
            case (false, true):
                return false
            default:
                return lhs.id < rhs.id
            }
        }
    }

    private func makeLoadedModel(
        manifest: SentimentModelManifest,
        provider: SentimentModelProviderManifest,
        modelURL: URL
    ) throws -> SentimentLoadedModel {
        let model = try modelLoader(modelURL)
        guard let inputKind = resolveInputKind(
            provider: provider,
            inputs: model.modelDescription.inputDescriptionsByName
        ) else {
            throw SentimentModelError.invalidModelInterface
        }

        let outputNames = model.modelDescription.outputDescriptionsByName
        let scalarOutputNames = scalarOutputNameMap(from: outputNames, labelMap: provider.labelMap)
        let labelOutputName = model.modelDescription.predictedFeatureName ?? outputNames.first {
            $0.value.type == .string
        }?.key

        if model.modelDescription.predictedProbabilitiesName == nil,
           scalarOutputNames.count != SentimentLabel.allCases.count,
           labelOutputName == nil {
            throw SentimentModelError.invalidModelInterface
        }

        let providerFamily = resolveProviderFamily(
            provider: provider,
            inputKind: inputKind
        )
        return SentimentLoadedModel(
            model: model,
            inputKind: inputKind,
            providerID: provider.id,
            providerRevision: provider.revision ?? provider.id,
            providerFamily: providerFamily,
            resourceRevision: manifest.revision,
            predictedProbabilitiesName: model.modelDescription.predictedProbabilitiesName,
            predictedFeatureName: model.modelDescription.predictedFeatureName,
            labelOutputName: labelOutputName,
            scalarOutputNames: scalarOutputNames,
            labelAliases: labelAliases(from: provider.labelMap),
            defaultConfidenceFloor: provider.confidenceFloor
                ?? manifest.confidenceFloor
                ?? Constants.defaultConfidenceFloor,
            defaultMarginFloor: provider.marginFloor
                ?? manifest.marginFloor
                ?? Constants.defaultMarginFloor,
            maxCharactersPerUnit: max(
                32,
                provider.maxCharactersPerUnit
                    ?? manifest.maxCharactersPerUnit
                    ?? Constants.defaultMaxCharactersPerUnit
            ),
            supportsSentenceLevelAggregation: provider.supportsSentenceLevelAggregation
                ?? manifest.supportsSentenceLevelAggregation
                ?? true,
            sizeHintMB: provider.sizeHintMB
        )
    }

    private func resolveInputKind(
        provider: SentimentModelProviderManifest,
        inputs: [String: MLFeatureDescription]
    ) -> SentimentModelInputKind? {
        if let inputSchema = provider.inputSchema {
            switch inputSchema.kind {
            case .text:
                let featureName = inputSchema.textFeatureName ?? inputs.first(where: {
                    $0.value.type == .string
                })?.key
                return featureName.map { .text(featureName: $0) }
            case .denseFeatures:
                let featureNames = (inputSchema.denseFeatureNames?.isEmpty == false)
                    ? inputSchema.denseFeatureNames!
                    : denseFeatureNames(from: inputs)
                guard !featureNames.isEmpty else { return nil }
                return .denseFeatures(featureNames: featureNames)
            case .tokenizedText:
                guard let inputIDsFeatureName = inputSchema.inputIDsFeatureName,
                      let attentionMaskFeatureName = inputSchema.attentionMaskFeatureName else {
                    return nil
                }
                return .tokenizedText(
                    inputIDsFeatureName: inputIDsFeatureName,
                    attentionMaskFeatureName: attentionMaskFeatureName,
                    tokenTypeIDsFeatureName: inputSchema.tokenTypeIDsFeatureName,
                    maxSequenceLength: max(
                        8,
                        inputSchema.maxSequenceLength ?? Constants.defaultTokenSequenceLength
                    )
                )
            }
        }

        if let inputFeatureName = inputs.first(where: { $0.value.type == .string })?.key {
            return .text(featureName: inputFeatureName)
        }
        let denseFeatureNames = denseFeatureNames(from: inputs)
        if !denseFeatureNames.isEmpty {
            return .denseFeatures(featureNames: denseFeatureNames)
        }
        return nil
    }

    private func resolveProviderFamily(
        provider: SentimentModelProviderManifest,
        inputKind: SentimentModelInputKind
    ) -> SentimentModelProviderFamily {
        if let providerFamily = provider.providerFamily {
            return providerFamily
        }
        switch inputKind {
        case .denseFeatures:
            return .embeddingLogReg
        case .text:
            return .textMaxEnt
        case .tokenizedText:
            return .transformerCoreML
        }
    }

    private func withCachedManifest<T>(
        _ operation: (inout SentimentModelManifest?) -> T
    ) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return operation(&cachedManifest)
    }

    private func withCachedModels<T>(
        _ operation: (inout [String: SentimentLoadedModel]) -> T
    ) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return operation(&cachedModels)
    }

    private func scalarOutputNameMap(
        from outputs: [String: MLFeatureDescription],
        labelMap: [String: String]?
    ) -> [SentimentLabel: String] {
        var result: [SentimentLabel: String] = [:]
        for label in SentimentLabel.allCases {
            let configuredOutput = labelMap?[label.rawValue]
            let outputName = ([configuredOutput].compactMap { $0 } + candidateOutputNames(for: label))
                .first(where: { name in
                    guard let feature = outputs[name] else { return false }
                    return feature.type == .double || feature.type == .int64
                })
            if let outputName {
                result[label] = outputName
            }
        }
        return result
    }

    private func labelAliases(
        from labelMap: [String: String]?
    ) -> [String: SentimentLabel] {
        guard let labelMap else { return [:] }
        return labelMap.reduce(into: [String: SentimentLabel]()) { partial, entry in
            guard let label = SentimentLabel(rawValue: entry.key) else { return }
            partial[entry.key.lowercased()] = label
            partial[entry.value.lowercased()] = label
        }
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
