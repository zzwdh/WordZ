#!/usr/bin/env swift

import Foundation

struct TopicTrainingDocument: Decodable {
    let id: String
    let label: String
    let text: String
}

struct TopicTrainingCorpus: Decodable {
    let documents: [TopicTrainingDocument]
}

struct TopicLocalEmbeddingResource: Encodable {
    let revision: String
    let dimensions: Int
    let seed: String
    let hashesPerFeature: Int
    let unigramWeight: Double
    let keywordWeight: Double
    let bigramWeight: Double
    let oovWeight: Double
    let subwordMinLength: Int
    let subwordMaxLength: Int
    let tokenEmbeddings: [String: [String: Double]]
    let bigramEmbeddings: [String: [String: Double]]
}

struct CLIOptions {
    let datasetPath: String
    let outputPath: String
    let version: String
    let revision: String
}

struct TermStats {
    var frequency = 0
    var documentFrequency = 0
    var labelHistogram: [String: Int] = [:]
}

struct PreparedDocument {
    let id: String
    let label: String
    let unigrams: [String]
    let bigrams: [String]
}

enum ScriptError: LocalizedError {
    case missingArgument(String)
    case invalidDataset

    var errorDescription: String? {
        switch self {
        case .missingArgument(let argument):
            return "Missing required argument: \(argument)"
        case .invalidDataset:
            return "Topic training dataset is empty or malformed."
        }
    }
}

enum TrainTopicModelScript {
    private static let dimensions = 384
    private static let maxUnigrams = 1200
    private static let maxBigrams = 400
    private static let sparseDimensionsPerTerm = 6
    private static let powerIterationLimit = 96
    private static let powerIterationTolerance = 1e-7
    private static let zeroTolerance = 1e-9
    private static let tokenRegex = try! NSRegularExpression(pattern: "[a-z]+")

    private static let defaultStopwords: Set<String> = [
        "a", "about", "across", "after", "against", "all", "also", "an", "and", "any",
        "are", "as", "at", "be", "before", "between", "both", "by", "can", "compare",
        "compared", "during", "each", "for", "from", "has", "have", "in", "into", "is",
        "it", "its", "of", "on", "or", "over", "same", "several", "so", "that", "the",
        "their", "them", "these", "this", "through", "to", "under", "used", "using",
        "was", "were", "with"
    ]

    static func run() throws {
        let options = try parseOptions(arguments: Array(CommandLine.arguments.dropFirst()))
        let datasetURL = URL(fileURLWithPath: options.datasetPath)
        let outputURL = URL(fileURLWithPath: options.outputPath)
        let repositoryRoot = scriptURL()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let data = try Data(contentsOf: datasetURL)
        let corpus = try JSONDecoder().decode(TopicTrainingCorpus.self, from: data)
        guard !corpus.documents.isEmpty else {
            throw ScriptError.invalidDataset
        }

        let repoDocuments = loadRepositoryDocuments(root: repositoryRoot)
        let preparedDocuments = (corpus.documents + repoDocuments).map(prepareDocument)
        guard !preparedDocuments.isEmpty else {
            throw ScriptError.invalidDataset
        }

        let unigramStats = collectTermStats(
            from: preparedDocuments,
            extractor: \.unigrams
        )
        let bigramStats = collectTermStats(
            from: preparedDocuments,
            extractor: \.bigrams
        )

        let selectedUnigrams = rankTerms(
            stats: unigramStats,
            documentCount: preparedDocuments.count,
            cap: Self.maxUnigrams
        )
        let selectedBigrams = rankTerms(
            stats: bigramStats,
            documentCount: preparedDocuments.count,
            cap: Self.maxBigrams
        )

        let tokenEmbeddings = computeSparseEmbeddings(
            terms: selectedUnigrams,
            stats: unigramStats,
            documents: preparedDocuments,
            extractor: \.unigrams,
            dimensions: Self.dimensions
        )
        let bigramEmbeddings = computeSparseEmbeddings(
            terms: selectedBigrams,
            stats: bigramStats,
            documents: preparedDocuments,
            extractor: \.bigrams,
            dimensions: Self.dimensions
        )

        let resource = TopicLocalEmbeddingResource(
            revision: options.revision,
            dimensions: Self.dimensions,
            seed: "wordz-topics-local-english-v\(options.version)",
            hashesPerFeature: 4,
            unigramWeight: 0.88,
            keywordWeight: 1.60,
            bigramWeight: 2.05,
            oovWeight: 0.10,
            subwordMinLength: 3,
            subwordMaxLength: 6,
            tokenEmbeddings: tokenEmbeddings,
            bigramEmbeddings: bigramEmbeddings
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let encoded = try encoder.encode(resource)

        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoded.write(to: outputURL)

        print("Generated topic model \(options.revision)")
        print("Documents: \(preparedDocuments.count)")
        print("Unigrams: \(tokenEmbeddings.count)")
        print("Bigrams: \(bigramEmbeddings.count)")
        print("Output: \(outputURL.path)")
    }

    private static func loadRepositoryDocuments(root: URL) -> [TopicTrainingDocument] {
        let candidatePaths = [
            "README.md",
            "Sources/WordZMac/README.md",
            "Sources/WordZMac/Analysis/README.md",
            "Sources/WordZMac/App/README.md"
        ]

        return candidatePaths.enumerated().compactMap { index, relativePath in
            let url = root.appendingPathComponent(relativePath)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
            return TopicTrainingDocument(
                id: "repo-\(index + 1)",
                label: "repo",
                text: text
            )
        }
    }

    private static func prepareDocument(_ document: TopicTrainingDocument) -> PreparedDocument {
        let tokens = tokenize(document.text)
        return PreparedDocument(
            id: document.id,
            label: document.label,
            unigrams: tokens,
            bigrams: zip(tokens, tokens.dropFirst()).map { "\($0.0) \($0.1)" }
        )
    }

    private static func tokenize(_ text: String) -> [String] {
        let lowered = text.lowercased()
        let range = NSRange(lowered.startIndex..<lowered.endIndex, in: lowered)
        let normalized = Self.tokenRegex.matches(in: lowered, range: range).compactMap { match -> String? in
            guard let tokenRange = Range(match.range, in: lowered) else { return nil }
            return canonicalize(String(lowered[tokenRange]))
        }
        return normalized.filter { token in
            token.count > 1 && !Self.defaultStopwords.contains(token)
        }
    }

    private static func canonicalize(_ token: String) -> String {
        if token.hasSuffix("ies"), token.count > 3 {
            return String(token.dropLast(3)) + "y"
        }
        if token.hasSuffix("s"), !token.hasSuffix("ss"), token.count > 3 {
            return String(token.dropLast())
        }
        return token
    }

    private static func collectTermStats(
        from documents: [PreparedDocument],
        extractor: KeyPath<PreparedDocument, [String]>
    ) -> [String: TermStats] {
        var stats: [String: TermStats] = [:]
        for document in documents {
            let terms = document[keyPath: extractor]
            let termCounts = Dictionary(grouping: terms, by: { $0 }).mapValues(\.count)
            for (term, count) in termCounts {
                stats[term, default: TermStats()].frequency += count
                stats[term, default: TermStats()].documentFrequency += 1
                stats[term, default: TermStats()].labelHistogram[document.label, default: 0] += 1
            }
        }
        return stats
    }

    private static func rankTerms(
        stats: [String: TermStats],
        documentCount: Int,
        cap: Int
    ) -> [String] {
        stats
            .map { term, stat -> (String, Double) in
                let df = Double(max(1, stat.documentFrequency))
                let idf = log(1 + (Double(documentCount) / df))
                let contrast = contrastiveScore(stat.labelHistogram)
                let score = Double(stat.frequency) * idf * (1 + contrast)
                return (term, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 {
                    return lhs.0 < rhs.0
                }
                return lhs.1 > rhs.1
            }
            .prefix(cap)
            .map(\.0)
    }

    private static func contrastiveScore(_ histogram: [String: Int]) -> Double {
        let counts = histogram.values.sorted(by: >)
        guard let first = counts.first else { return 0 }
        let second = counts.dropFirst().first ?? 0
        return Double(max(0, first - second)) / Double(max(1, first))
    }

    private static func computeSparseEmbeddings(
        terms: [String],
        stats: [String: TermStats],
        documents: [PreparedDocument],
        extractor: KeyPath<PreparedDocument, [String]>,
        dimensions: Int
    ) -> [String: [String: Double]] {
        guard !terms.isEmpty else { return [:] }

        let matrix = makeCenteredTFIDFMatrix(
            terms: terms,
            stats: stats,
            documents: documents,
            extractor: extractor
        )
        let effectiveDimensions = min(
            dimensions,
            terms.count,
            max(1, documents.count - 1)
        )
        let eigenpairs = leadingEigenpairs(
            covarianceMatrix: covarianceMatrix(from: matrix),
            dimension: matrix.columnCount,
            targetDimensions: effectiveDimensions
        )
        guard !eigenpairs.eigenvectors.isEmpty else { return [:] }

        return Dictionary(uniqueKeysWithValues: terms.enumerated().map { termIndex, term in
            let dense = denseEmbedding(
                termIndex: termIndex,
                eigenvectors: eigenpairs.eigenvectors,
                eigenvalues: eigenpairs.eigenvalues,
                dimensions: dimensions
            )
            return (term, sparseEmbedding(from: normalize(dense)))
        })
    }

    private static func makeCenteredTFIDFMatrix(
        terms: [String],
        stats: [String: TermStats],
        documents: [PreparedDocument],
        extractor: KeyPath<PreparedDocument, [String]>
    ) -> (rowCount: Int, columnCount: Int, flattened: [Double]) {
        let rowCount = documents.count
        let columnCount = terms.count
        let termIndices = Dictionary(uniqueKeysWithValues: terms.enumerated().map { ($1, $0) })
        var flattened = Array(repeating: 0.0, count: rowCount * columnCount)
        var means = Array(repeating: 0.0, count: columnCount)

        for (rowIndex, document) in documents.enumerated() {
            let counts = Dictionary(grouping: document[keyPath: extractor], by: { $0 }).mapValues(\.count)
            for (term, count) in counts {
                guard let columnIndex = termIndices[term] else { continue }
                let df = Double(max(1, stats[term]?.documentFrequency ?? 1))
                let idf = log(1 + (Double(max(1, rowCount)) / df))
                let value = log1p(Double(count)) * idf
                flattened[(rowIndex * columnCount) + columnIndex] = value
                means[columnIndex] += value
            }
        }

        if rowCount > 0 {
            for index in means.indices {
                means[index] /= Double(rowCount)
            }
            for rowIndex in 0..<rowCount {
                for columnIndex in 0..<columnCount {
                    flattened[(rowIndex * columnCount) + columnIndex] -= means[columnIndex]
                }
            }
        }

        return (rowCount, columnCount, flattened)
    }

    private static func covarianceMatrix(
        from matrix: (rowCount: Int, columnCount: Int, flattened: [Double])
    ) -> [Double] {
        let denominator = Double(max(1, matrix.rowCount - 1))
        var covariance = Array(repeating: 0.0, count: matrix.columnCount * matrix.columnCount)

        for row in 0..<matrix.columnCount {
            for column in row..<matrix.columnCount {
                var total = 0.0
                for documentIndex in 0..<matrix.rowCount {
                    let left = matrix.flattened[(documentIndex * matrix.columnCount) + row]
                    let right = matrix.flattened[(documentIndex * matrix.columnCount) + column]
                    total += left * right
                }
                let value = total / denominator
                covariance[(row * matrix.columnCount) + column] = value
                covariance[(column * matrix.columnCount) + row] = value
            }
        }

        return covariance
    }

    private static func leadingEigenpairs(
        covarianceMatrix: [Double],
        dimension: Int,
        targetDimensions: Int
    ) -> (eigenvectors: [[Double]], eigenvalues: [Double]) {
        var working = covarianceMatrix
        var eigenvectors: [[Double]] = []
        var eigenvalues: [Double] = []

        for component in 0..<targetDimensions {
            guard let pair = leadingEigenpair(
                matrix: working,
                dimension: dimension,
                seed: component
            ) else {
                break
            }
            if pair.value <= Self.zeroTolerance {
                break
            }

            eigenvectors.append(pair.vector)
            eigenvalues.append(pair.value)

            for row in 0..<dimension {
                for column in 0..<dimension {
                    working[(row * dimension) + column] -= pair.value * pair.vector[row] * pair.vector[column]
                }
            }
        }

        return (eigenvectors, eigenvalues)
    }

    private static func leadingEigenpair(
        matrix: [Double],
        dimension: Int,
        seed: Int
    ) -> (vector: [Double], value: Double)? {
        guard dimension > 0 else { return nil }

        var vector = Array(repeating: 0.0, count: dimension)
        let seedIndex = min(dimension - 1, max(0, (seed * 17) % max(1, dimension)))
        vector[seedIndex] = 1
        vector = normalize(vector)

        var previousValue = -Double.infinity
        for _ in 0..<Self.powerIterationLimit {
            let multiplied = multiply(matrix: matrix, vector: vector, dimension: dimension)
            let normalized = normalize(multiplied)
            let value = rayleighQuotient(
                matrix: matrix,
                vector: normalized,
                dimension: dimension
            )
            if abs(value - previousValue) < Self.powerIterationTolerance {
                vector = normalized
                previousValue = value
                break
            }
            vector = normalized
            previousValue = value
        }

        guard previousValue.isFinite, previousValue > Self.zeroTolerance else {
            return nil
        }

        return (vector, previousValue)
    }

    private static func multiply(
        matrix: [Double],
        vector: [Double],
        dimension: Int
    ) -> [Double] {
        var result = Array(repeating: 0.0, count: dimension)
        for row in 0..<dimension {
            var total = 0.0
            for column in 0..<dimension {
                total += matrix[(row * dimension) + column] * vector[column]
            }
            result[row] = total
        }
        return result
    }

    private static func rayleighQuotient(
        matrix: [Double],
        vector: [Double],
        dimension: Int
    ) -> Double {
        let multiplied = multiply(matrix: matrix, vector: vector, dimension: dimension)
        return zip(vector, multiplied).reduce(0.0) { $0 + ($1.0 * $1.1) }
    }

    private static func denseEmbedding(
        termIndex: Int,
        eigenvectors: [[Double]],
        eigenvalues: [Double],
        dimensions: Int
    ) -> [Double] {
        var dense = Array(repeating: 0.0, count: dimensions)
        for component in 0..<min(eigenvectors.count, dimensions) {
            dense[component] = eigenvectors[component][termIndex] * sqrt(max(0, eigenvalues[component]))
        }
        return dense
    }

    private static func sparseEmbedding(from dense: [Double]) -> [String: Double] {
        let selected = dense.enumerated()
            .filter { abs($0.element) > Self.zeroTolerance }
            .sorted { abs($0.element) > abs($1.element) }
            .prefix(Self.sparseDimensionsPerTerm)

        return Dictionary(uniqueKeysWithValues: selected.map { index, value in
            (String(index), (value * 1000).rounded() / 1000)
        })
    }

    private static func normalize(_ vector: [Double]) -> [Double] {
        let magnitude = sqrt(vector.reduce(0.0) { $0 + ($1 * $1) })
        guard magnitude > Self.zeroTolerance else { return vector }
        return vector.map { $0 / magnitude }
    }

    private static func scriptURL() -> URL {
        URL(fileURLWithPath: #filePath)
    }

    private static func parseOptions(arguments: [String]) throws -> CLIOptions {
        var datasetPath: String?
        var outputPath: String?
        var version = "3"
        var revision = "2026-04-local-v3"

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
            case "--revision":
                index += 1
                revision = safeArgument(at: index, in: arguments) ?? revision
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
            revision: revision
        )
    }

    private static func safeArgument(
        at index: Int,
        in arguments: [String]
    ) -> String? {
        guard arguments.indices.contains(index) else { return nil }
        return arguments[index]
    }
}

do {
    try TrainTopicModelScript.run()
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
