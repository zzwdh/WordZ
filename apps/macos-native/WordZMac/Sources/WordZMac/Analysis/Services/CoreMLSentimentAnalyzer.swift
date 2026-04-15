import CoreML
import Foundation
import NaturalLanguage

private struct SentimentModelProbability {
    let positive: Double
    let neutral: Double
    let negative: Double
    let derivedFromLabelOnly: Bool

    var finalLabel: SentimentLabel {
        let ranked = rankedLabels
        let top = ranked[0]
        let runnerUp = ranked[1]
        if top.score < 0.55 || (top.score - runnerUp.score) < 0.12 {
            return .neutral
        }
        return top.label
    }

    var confidence: Double {
        rankedLabels[0].score
    }

    var topMargin: Double {
        rankedLabels[0].score - rankedLabels[1].score
    }

    private var rankedLabels: [(label: SentimentLabel, score: Double)] {
        [
            (.positive, positive),
            (.neutral, neutral),
            (.negative, negative)
        ]
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.label.rawValue < rhs.label.rawValue
            }
            return lhs.score > rhs.score
        }
    }
}

private struct SentimentModelRowUnit {
    let id: String
    let sourceID: String?
    let sourceTitle: String
    let groupID: String?
    let groupTitle: String?
    let text: String
    let sentenceID: Int?
    let tokenIndex: Int?
}

final class CoreMLSentimentAnalyzer: SentimentAnalyzing {
    private let modelManager: SentimentModelManager
    private let indexDocument: (String, DocumentCacheKey?) -> ParsedDocumentIndex
    private let sentenceEmbedding: NLEmbedding?

    init(
        modelManager: SentimentModelManager,
        indexDocument: @escaping (String, DocumentCacheKey?) -> ParsedDocumentIndex
    ) {
        self.modelManager = modelManager
        self.indexDocument = indexDocument
        self.sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    func analyze(_ request: SentimentRunRequest) throws -> SentimentRunResult {
        let loadedModel = try modelManager.loadModel()
        let rows: [SentimentRowResult]
        switch request.unit {
        case .document:
            rows = try request.texts.map {
                try analyzeDocument($0, request: request, model: loadedModel)
            }
        case .sentence:
            rows = try buildSentenceUnits(request: request).map {
                try classify(unit: $0, model: loadedModel, aggregatedFrom: .direct, subunitCount: nil)
            }
        case .concordanceLine:
            rows = try buildConcordanceUnits(request: request).map {
                try classify(unit: $0, model: loadedModel, aggregatedFrom: .direct, subunitCount: nil)
            }
        }

        return SentimentResultAggregation.makeRunResult(
            request: request,
            backendKind: .coreML,
            backendRevision: loadedModel.providerRevision,
            resourceRevision: loadedModel.resourceRevision,
            supportsEvidenceHits: false,
            rows: rows,
            lexiconVersion: ""
        )
    }

    private func analyzeDocument(
        _ input: SentimentInputText,
        request: SentimentRunRequest,
        model: SentimentLoadedModel
    ) throws -> SentimentRowResult {
        let text = resolveText(for: input, request: request)
        let indexed = indexDocument(text, DocumentCacheKey(text: text))
        let sentenceUnits = indexed.document.sentences.map { sentence in
            SentimentModelRowUnit(
                id: "\(input.id)::sentence::\(sentence.sentenceId)",
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: sentence.text,
                sentenceID: sentence.sentenceId,
                tokenIndex: sentence.tokens.first?.tokenIndex
            )
        }

        let probabilities: [SentimentModelProbability]
        if sentenceUnits.isEmpty {
            probabilities = [try predict(text: text, model: model)]
        } else {
            probabilities = try sentenceUnits.map { try predict(text: $0.text, model: model) }
        }

        let count = Double(max(probabilities.count, 1))
        let positive = probabilities.reduce(0.0) { $0 + $1.positive } / count
        let neutral = probabilities.reduce(0.0) { $0 + $1.neutral } / count
        let negative = probabilities.reduce(0.0) { $0 + $1.negative } / count
        let aggregate = SentimentModelProbability(
            positive: positive,
            neutral: neutral,
            negative: negative,
            derivedFromLabelOnly: probabilities.allSatisfy(\.derivedFromLabelOnly)
        )
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: false,
            ruleSummary: nil,
            scopeNotes: aggregate.derivedFromLabelOnly ? ["label_only_model_output"] : [],
            confidence: aggregate.confidence,
            topMargin: aggregate.topMargin,
            subunitCount: sentenceUnits.isEmpty ? 1 : sentenceUnits.count,
            truncated: false,
            aggregatedFrom: .sentenceMean,
            modelRevision: model.providerRevision
        )

        return SentimentRowResult(
            id: input.id,
            sourceID: input.sourceID,
            sourceTitle: input.sourceTitle,
            groupID: input.groupID,
            groupTitle: input.groupTitle,
            text: text,
            positivityScore: positive,
            negativityScore: negative,
            neutralityScore: neutral,
            finalLabel: aggregate.finalLabel,
            netScore: positive - negative,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: diagnostics,
            sentenceID: input.sentenceID,
            tokenIndex: input.tokenIndex
        )
    }

    private func buildSentenceUnits(request: SentimentRunRequest) -> [SentimentModelRowUnit] {
        request.texts.flatMap { input in
            let text = resolveText(for: input, request: request)
            let indexed = indexDocument(text, DocumentCacheKey(text: text))
            return indexed.document.sentences.map { sentence in
                SentimentModelRowUnit(
                    id: "\(input.id)::sentence::\(sentence.sentenceId)",
                    sourceID: input.sourceID,
                    sourceTitle: input.sourceTitle,
                    groupID: input.groupID,
                    groupTitle: input.groupTitle,
                    text: sentence.text,
                    sentenceID: sentence.sentenceId,
                    tokenIndex: sentence.tokens.first?.tokenIndex
                )
            }
        }
    }

    private func buildConcordanceUnits(request: SentimentRunRequest) -> [SentimentModelRowUnit] {
        request.texts.map { input in
            let text = resolveText(for: input, request: request)
            return SentimentModelRowUnit(
                id: input.id,
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: text,
                sentenceID: input.sentenceID,
                tokenIndex: input.tokenIndex
            )
        }
    }

    private func classify(
        unit: SentimentModelRowUnit,
        model: SentimentLoadedModel,
        aggregatedFrom: SentimentAggregationMode,
        subunitCount: Int?
    ) throws -> SentimentRowResult {
        let probability = try predict(text: unit.text, model: model)
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: false,
            ruleSummary: nil,
            scopeNotes: probability.derivedFromLabelOnly ? ["label_only_model_output"] : [],
            confidence: probability.confidence,
            topMargin: probability.topMargin,
            subunitCount: subunitCount,
            truncated: false,
            aggregatedFrom: aggregatedFrom,
            modelRevision: model.providerRevision
        )

        return SentimentRowResult(
            id: unit.id,
            sourceID: unit.sourceID,
            sourceTitle: unit.sourceTitle,
            groupID: unit.groupID,
            groupTitle: unit.groupTitle,
            text: unit.text,
            positivityScore: probability.positive,
            negativityScore: probability.negative,
            neutralityScore: probability.neutral,
            finalLabel: probability.finalLabel,
            netScore: probability.positive - probability.negative,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: diagnostics,
            sentenceID: unit.sentenceID,
            tokenIndex: unit.tokenIndex
        )
    }

    private func predict(
        text: String,
        model: SentimentLoadedModel
    ) throws -> SentimentModelProbability {
        let provider = try featureProvider(for: text, model: model)
        let prediction = try model.model.prediction(from: provider)

        if let probabilityOutputName = model.predictedProbabilitiesName,
           let featureValue = prediction.featureValue(for: probabilityOutputName),
           let mapped = mapProbabilities(from: featureValue.dictionaryValue as? [String: NSNumber]) {
            return mapped
        }

        if !model.scalarOutputNames.isEmpty {
            let probabilities = model.scalarOutputNames.reduce(into: [SentimentLabel: Double]()) { partial, entry in
                let value = prediction.featureValue(for: entry.value)
                partial[entry.key] = value?.doubleValue ?? Double(value?.int64Value ?? 0)
            }
            if let normalized = normalize(probabilities: probabilities) {
                return normalized
            }
        }

        let labelOutputName = model.predictedFeatureName ?? model.labelOutputName
        if let labelOutputName,
           let labelString = prediction.featureValue(for: labelOutputName)?.stringValue,
           let label = sentimentLabel(from: labelString) {
            return synthesizedProbability(for: label)
        }

        throw SentimentModelError.invalidModelInterface
    }

    private func featureProvider(
        for text: String,
        model: SentimentLoadedModel
    ) throws -> MLDictionaryFeatureProvider {
        switch model.inputKind {
        case .text(let featureName):
            return try MLDictionaryFeatureProvider(dictionary: [
                featureName: text
            ])
        case .denseFeatures(let featureNames):
            let vector = denseSentenceVector(for: text, expectedCount: featureNames.count)
            let dictionary = Dictionary(uniqueKeysWithValues: featureNames.enumerated().map { index, featureName in
                (featureName, NSNumber(value: vector[index]))
            })
            return try MLDictionaryFeatureProvider(dictionary: dictionary)
        }
    }

    private func mapProbabilities(
        from values: [String: NSNumber]?
    ) -> SentimentModelProbability? {
        guard let values else { return nil }
        let probabilities = values.reduce(into: [SentimentLabel: Double]()) { partial, entry in
            guard let label = sentimentLabel(from: entry.key) else { return }
            partial[label] = entry.value.doubleValue
        }
        return normalize(probabilities: probabilities)
    }

    private func normalize(
        probabilities: [SentimentLabel: Double]
    ) -> SentimentModelProbability? {
        let positive = max(0, probabilities[.positive] ?? 0)
        let neutral = max(0, probabilities[.neutral] ?? 0)
        let negative = max(0, probabilities[.negative] ?? 0)
        let total = positive + neutral + negative
        guard total > 0 else { return nil }
        return SentimentModelProbability(
            positive: positive / total,
            neutral: neutral / total,
            negative: negative / total,
            derivedFromLabelOnly: false
        )
    }

    private func synthesizedProbability(for label: SentimentLabel) -> SentimentModelProbability {
        switch label {
        case .positive:
            return SentimentModelProbability(
                positive: 0.72,
                neutral: 0.18,
                negative: 0.10,
                derivedFromLabelOnly: true
            )
        case .neutral:
            return SentimentModelProbability(
                positive: 0.15,
                neutral: 0.70,
                negative: 0.15,
                derivedFromLabelOnly: true
            )
        case .negative:
            return SentimentModelProbability(
                positive: 0.10,
                neutral: 0.18,
                negative: 0.72,
                derivedFromLabelOnly: true
            )
        }
    }

    private func sentimentLabel(from raw: String) -> SentimentLabel? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("positive") || normalized == "pos" {
            return .positive
        }
        if normalized.contains("negative") || normalized == "neg" {
            return .negative
        }
        if normalized.contains("neutral") || normalized == "neu" {
            return .neutral
        }
        return nil
    }

    private func denseSentenceVector(
        for text: String,
        expectedCount: Int
    ) -> [Double] {
        guard expectedCount > 0 else { return [] }
        guard let rawVector = sentenceEmbedding?.vector(for: text) else {
            return Array(repeating: 0, count: expectedCount)
        }

        var values = rawVector.map { Double($0) }
        if values.count > expectedCount {
            values.removeSubrange(expectedCount...)
            return values
        }
        if values.count < expectedCount {
            values.append(contentsOf: repeatElement(0, count: expectedCount - values.count))
        }
        return values
    }

    private func resolveText(
        for input: SentimentInputText,
        request: SentimentRunRequest
    ) -> String {
        guard request.unit == .concordanceLine,
              request.contextBasis == .fullSentenceWhenAvailable,
              let documentText = input.documentText,
              let sentenceID = input.sentenceID else {
            return input.text
        }
        let indexed = indexDocument(documentText, DocumentCacheKey(text: documentText))
        return indexed.document.sentences.first(where: { $0.sentenceId == sentenceID })?.text ?? input.text
    }
}
