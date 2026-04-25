import CoreML
import Foundation
import NaturalLanguage

private struct SentimentModelProbability {
    let positive: Double
    let neutral: Double
    let negative: Double
    let derivedFromLabelOnly: Bool

    func finalLabel(
        confidenceFloor: Double,
        marginFloor: Double
    ) -> SentimentLabel {
        let ranked = rankedLabels
        let top = ranked[0]
        let runnerUp = ranked[1]
        if top.score < confidenceFloor || (top.score - runnerUp.score) < marginFloor {
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

private struct SentimentPreparedText {
    let text: String
    let truncated: Bool
}

private struct SentimentModelPrediction {
    let probability: SentimentModelProbability
    let truncated: Bool
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

struct SentimentTokenizationResult {
    let inputIDs: [Int]
    let attentionMask: [Int]
    let tokenTypeIDs: [Int]?
    let truncated: Bool
}

protocol SentimentTokenizing {
    func tokenize(
        _ text: String,
        maxLength: Int
    ) throws -> SentimentTokenizationResult
}

private protocol SentimentModelPredicting {
    func featureProvider(
        for text: String,
        model: SentimentLoadedModel
    ) throws -> MLFeatureProvider
}

private struct TextFeatureSentimentPredictor: SentimentModelPredicting {
    func featureProvider(
        for text: String,
        model: SentimentLoadedModel
    ) throws -> MLFeatureProvider {
        guard case .text(let featureName) = model.inputKind else {
            throw SentimentModelError.invalidModelInterface
        }
        return try MLDictionaryFeatureProvider(dictionary: [
            featureName: text
        ])
    }
}

private struct DenseFeatureSentimentPredictor: SentimentModelPredicting {
    let sentenceEmbedding: NLEmbedding?

    func featureProvider(
        for text: String,
        model: SentimentLoadedModel
    ) throws -> MLFeatureProvider {
        guard case .denseFeatures(let featureNames) = model.inputKind else {
            throw SentimentModelError.invalidModelInterface
        }
        let vector = denseSentenceVector(
            for: text,
            expectedCount: featureNames.count,
            sentenceEmbedding: sentenceEmbedding
        )
        let dictionary = Dictionary(uniqueKeysWithValues: featureNames.enumerated().map { index, featureName in
            (featureName, NSNumber(value: vector[index]))
        })
        return try MLDictionaryFeatureProvider(dictionary: dictionary)
    }

    private func denseSentenceVector(
        for text: String,
        expectedCount: Int,
        sentenceEmbedding: NLEmbedding?
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
}

private struct TokenizedCoreMLSentimentPredictor: SentimentModelPredicting {
    let tokenizer: SentimentTokenizing?

    func featureProvider(
        for text: String,
        model: SentimentLoadedModel
    ) throws -> MLFeatureProvider {
        guard case .tokenizedText(
            let inputIDsFeatureName,
            let attentionMaskFeatureName,
            let tokenTypeIDsFeatureName,
            let maxSequenceLength
        ) = model.inputKind else {
            throw SentimentModelError.invalidModelInterface
        }
        guard let tokenizer else {
            throw SentimentModelError.invalidModelInterface
        }

        let tokenized = try tokenizer.tokenize(text, maxLength: maxSequenceLength)
        let inputIDsArray = try makeMLMultiArray(tokenized.inputIDs)
        let attentionMaskArray = try makeMLMultiArray(tokenized.attentionMask)

        var dictionary: [String: Any] = [
            inputIDsFeatureName: inputIDsArray,
            attentionMaskFeatureName: attentionMaskArray
        ]
        if let tokenTypeIDsFeatureName,
           let tokenTypeIDs = tokenized.tokenTypeIDs {
            dictionary[tokenTypeIDsFeatureName] = try makeMLMultiArray(tokenTypeIDs)
        }
        return try MLDictionaryFeatureProvider(dictionary: dictionary)
    }

    private func makeMLMultiArray(_ values: [Int]) throws -> MLMultiArray {
        let shape = [NSNumber(value: values.count)]
        let array = try MLMultiArray(shape: shape, dataType: .int32)
        for (index, value) in values.enumerated() {
            array[index] = NSNumber(value: value)
        }
        return array
    }
}

final class CoreMLSentimentAnalyzer: SentimentAnalyzing {
    private let modelManager: SentimentModelManager
    private let indexDocument: (String, DocumentCacheKey?) -> ParsedDocumentIndex
    private let sentenceEmbedding: NLEmbedding?
    private let tokenizer: SentimentTokenizing?

    init(
        modelManager: SentimentModelManager,
        indexDocument: @escaping (String, DocumentCacheKey?) -> ParsedDocumentIndex,
        tokenizer: SentimentTokenizing? = nil
    ) {
        self.modelManager = modelManager
        self.indexDocument = indexDocument
        self.sentenceEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
        self.tokenizer = tokenizer
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
        case .concordanceLine, .sourceSentence:
            rows = try buildConcordanceUnits(request: request).map {
                try classify(unit: $0, model: loadedModel, aggregatedFrom: .direct, subunitCount: nil)
            }
        }

        return SentimentResultAggregation.makeRunResult(
            request: request,
            backendKind: .coreML,
            backendRevision: loadedModel.providerRevision,
            resourceRevision: loadedModel.resourceRevision,
            providerID: loadedModel.providerID,
            providerFamily: loadedModel.providerFamily,
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
        let sentenceUnits = model.supportsSentenceLevelAggregation
            ? sentenceUnits(
                from: input,
                text: text,
                indexed: indexDocument(text, DocumentCacheKey(text: text))
            )
            : []

        if model.supportsSentenceLevelAggregation, !sentenceUnits.isEmpty {
            let weightedPredictions = try sentenceUnits.map { unit -> (prediction: SentimentModelPrediction, weight: Double) in
                let prediction = try predict(text: unit.text, model: model)
                return (
                    prediction,
                    sentenceAggregationWeight(
                        for: prediction,
                        text: unit.text,
                        request: request
                    )
                )
            }
            let weightTotal = max(weightedPredictions.reduce(0.0) { $0 + $1.weight }, 0.0001)
            let positive = weightedPredictions.reduce(0.0) { $0 + ($1.prediction.probability.positive * $1.weight) } / weightTotal
            let neutral = weightedPredictions.reduce(0.0) { $0 + ($1.prediction.probability.neutral * $1.weight) } / weightTotal
            let negative = weightedPredictions.reduce(0.0) { $0 + ($1.prediction.probability.negative * $1.weight) } / weightTotal
            let aggregate = SentimentModelProbability(
                positive: positive,
                neutral: neutral,
                negative: negative,
                derivedFromLabelOnly: weightedPredictions.allSatisfy { $0.prediction.probability.derivedFromLabelOnly }
            )
            let scopeNotes = modelScopeNotes(
                derivedFromLabelOnly: aggregate.derivedFromLabelOnly,
                truncated: weightedPredictions.contains(where: \.prediction.truncated),
                maxCharactersPerUnit: model.maxCharactersPerUnit
            )
            let diagnostics = SentimentRowDiagnostics(
                mixedEvidence: false,
                ruleSummary: nil,
                scopeNotes: scopeNotes,
                confidence: aggregate.confidence,
                topMargin: aggregate.topMargin,
                subunitCount: sentenceUnits.count,
                truncated: weightedPredictions.contains(where: \.prediction.truncated),
                aggregatedFrom: .sentenceMean,
                modelRevision: model.providerRevision,
                providerID: model.providerID,
                providerFamily: model.providerFamily,
                inferencePath: .model,
                modelInputKind: model.inputSchemaKind
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
                finalLabel: aggregate.finalLabel(
                    confidenceFloor: model.defaultConfidenceFloor,
                    marginFloor: model.defaultMarginFloor
                ),
                netScore: positive - negative,
                evidence: [],
                evidenceCount: 0,
                mixedEvidence: false,
                diagnostics: diagnostics,
                sentenceID: input.sentenceID,
                tokenIndex: input.tokenIndex
            )
        }

        return try classify(
            unit: SentimentModelRowUnit(
                id: input.id,
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: text,
                sentenceID: input.sentenceID,
                tokenIndex: input.tokenIndex
            ),
            model: model,
            aggregatedFrom: .direct,
            subunitCount: 1
        )
    }

    private func buildSentenceUnits(request: SentimentRunRequest) -> [SentimentModelRowUnit] {
        request.texts.flatMap { input in
            let text = resolveText(for: input, request: request)
            let indexed = indexDocument(text, DocumentCacheKey(text: text))
            return sentenceUnits(from: input, text: text, indexed: indexed)
        }
    }

    private func sentenceUnits(
        from input: SentimentInputText,
        text: String,
        indexed: ParsedDocumentIndex
    ) -> [SentimentModelRowUnit] {
        let units = indexed.document.sentences.map { sentence in
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
        if !units.isEmpty {
            return units
        }
        return [
            SentimentModelRowUnit(
                id: "\(input.id)::sentence::0",
                sourceID: input.sourceID,
                sourceTitle: input.sourceTitle,
                groupID: input.groupID,
                groupTitle: input.groupTitle,
                text: text,
                sentenceID: input.sentenceID ?? 0,
                tokenIndex: input.tokenIndex
            )
        ]
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
        let prediction = try predict(text: unit.text, model: model)
        let probability = prediction.probability
        let diagnostics = SentimentRowDiagnostics(
            mixedEvidence: false,
            ruleSummary: nil,
            scopeNotes: modelScopeNotes(
                derivedFromLabelOnly: probability.derivedFromLabelOnly,
                truncated: prediction.truncated,
                maxCharactersPerUnit: model.maxCharactersPerUnit
            ),
            confidence: probability.confidence,
            topMargin: probability.topMargin,
            subunitCount: subunitCount,
            truncated: prediction.truncated,
            aggregatedFrom: aggregatedFrom,
            modelRevision: model.providerRevision,
            providerID: model.providerID,
            providerFamily: model.providerFamily,
            inferencePath: .model,
            modelInputKind: model.inputSchemaKind
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
            finalLabel: probability.finalLabel(
                confidenceFloor: model.defaultConfidenceFloor,
                marginFloor: model.defaultMarginFloor
            ),
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
    ) throws -> SentimentModelPrediction {
        let preparedText = prepareText(text, maxCharacters: model.maxCharactersPerUnit)
        let predictor = predictor(for: model)
        let provider = try predictor.featureProvider(for: preparedText.text, model: model)
        let prediction = try model.model.prediction(from: provider)

        if let probabilityOutputName = model.predictedProbabilitiesName,
           let featureValue = prediction.featureValue(for: probabilityOutputName),
           let mapped = mapProbabilities(
            from: featureValue.dictionaryValue as? [String: NSNumber],
            labelAliases: model.labelAliases
           ) {
            return SentimentModelPrediction(
                probability: mapped,
                truncated: preparedText.truncated
            )
        }

        if !model.scalarOutputNames.isEmpty {
            let probabilities = model.scalarOutputNames.reduce(into: [SentimentLabel: Double]()) { partial, entry in
                let value = prediction.featureValue(for: entry.value)
                partial[entry.key] = value?.doubleValue ?? Double(value?.int64Value ?? 0)
            }
            if let normalized = normalize(probabilities: probabilities) {
                return SentimentModelPrediction(
                    probability: normalized,
                    truncated: preparedText.truncated
                )
            }
        }

        let labelOutputName = model.predictedFeatureName ?? model.labelOutputName
        if let labelOutputName,
           let labelString = prediction.featureValue(for: labelOutputName)?.stringValue,
           let label = sentimentLabel(from: labelString, labelAliases: model.labelAliases) {
            return SentimentModelPrediction(
                probability: synthesizedProbability(for: label),
                truncated: preparedText.truncated
            )
        }

        throw SentimentModelError.invalidModelInterface
    }

    private func predictor(for model: SentimentLoadedModel) -> SentimentModelPredicting {
        switch model.inputKind {
        case .text:
            return TextFeatureSentimentPredictor()
        case .denseFeatures:
            return DenseFeatureSentimentPredictor(sentenceEmbedding: sentenceEmbedding)
        case .tokenizedText:
            return TokenizedCoreMLSentimentPredictor(tokenizer: tokenizer)
        }
    }

    private func modelScopeNotes(
        derivedFromLabelOnly: Bool,
        truncated: Bool,
        maxCharactersPerUnit: Int
    ) -> [String] {
        var notes: [String] = []
        if derivedFromLabelOnly {
            notes.append("label_only_model_output")
        }
        if truncated {
            notes.append("truncated_to_\(maxCharactersPerUnit)_chars")
        }
        return notes
    }

    private func prepareText(
        _ text: String,
        maxCharacters: Int
    ) -> SentimentPreparedText {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > maxCharacters else {
            return SentimentPreparedText(text: normalized, truncated: false)
        }
        let truncated = String(normalized.prefix(maxCharacters))
        return SentimentPreparedText(text: truncated, truncated: true)
    }

    private func sentenceAggregationWeight(
        for prediction: SentimentModelPrediction,
        text: String,
        request: SentimentRunRequest
    ) -> Double {
        var weight = max(0.35, prediction.probability.confidence)
        weight *= max(0.45, 0.75 + prediction.probability.topMargin)

        if request.resolvedDomainPackID == .news,
           isProceduralNewsSentence(text),
           prediction.probability.neutral >= max(prediction.probability.positive, prediction.probability.negative) {
            weight *= 0.55
        }

        return weight
    }

    private func isProceduralNewsSentence(_ text: String) -> Bool {
        let normalized = text.localizedLowercase
        let proceduralPhrases = [
            "according to",
            "after the vote",
            "before noon",
            "court records",
            "in a court filing",
            "issued the notice",
            "issued the order",
            "released the statement",
            "the agency issued",
            "the hearing",
            "the filing",
            "the notice",
            "the statement",
            "the spokesperson said"
        ]
        return proceduralPhrases.contains(where: normalized.contains)
    }

    private func mapProbabilities(
        from values: [String: NSNumber]?,
        labelAliases: [String: SentimentLabel]
    ) -> SentimentModelProbability? {
        guard let values else { return nil }
        let probabilities = values.reduce(into: [SentimentLabel: Double]()) { partial, entry in
            guard let label = sentimentLabel(from: entry.key, labelAliases: labelAliases) else { return }
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

    private func sentimentLabel(
        from raw: String,
        labelAliases: [String: SentimentLabel] = [:]
    ) -> SentimentLabel? {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let aliased = labelAliases[normalized] {
            return aliased
        }
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

    private func resolveText(
        for input: SentimentInputText,
        request: SentimentRunRequest
    ) -> String {
        guard request.unit == .concordanceLine || request.unit == .sourceSentence,
              request.contextBasis == .fullSentenceWhenAvailable,
              let documentText = input.documentText,
              let sentenceID = input.sentenceID else {
            return input.text
        }
        let indexed = indexDocument(documentText, DocumentCacheKey(text: documentText))
        return indexed.document.sentences.first(where: { $0.sentenceId == sentenceID })?.text ?? input.text
    }
}
