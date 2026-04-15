import Accelerate
import Foundation

private struct TopicCenteredEmbeddingMatrix {
    let rowCount: Int
    let columnCount: Int
    let flattened: [Double]
}

extension NativeTopicEngine {
    private static let minimumPCASampleCount = 48
    private static let targetPCADimensions = 192
    private static let minimumPCAComponents = 48
    private static let minimumExplainedVariance = 0.97
    private static let targetExplainedVariance = 0.99
    private static let maxPowerIterations = 64
    private static let powerIterationTolerance = 1e-6
    private static let zeroTolerance = 1e-9

    func makeEmbeddings(
        for slices: [TopicTextSlice],
        model: TopicEmbeddingModel
    ) -> [[Double]] {
        let providerKey = [
            model.manifest.modelID,
            model.manifest.version,
            model.providerLabel,
            model.providerRevision
        ].joined(separator: "::")

        return slices.map { slice in
            let cacheKey = "\(providerKey)::\(slice.id)"
            if let cached = embeddingCache[cacheKey] {
                touchEmbeddingCacheKey(cacheKey)
                return cached
            }

            let input = slice.embeddingInput
            let embedded = model.vector(for: input)
                ?? model.vector(
                    for: TopicEmbeddingInput(
                        text: input.tokens.joined(separator: " "),
                        tokens: input.tokens,
                        keywordTerms: input.keywordTerms,
                        keywordBigrams: input.keywordBigrams
                    )
                )
                ?? Array(repeating: 0.0, count: max(32, model.expectedDimensions))
            let normalized = normalize(embedded)

            embeddingCache[cacheKey] = normalized
            embeddingCacheOrder.removeAll(where: { $0 == cacheKey })
            embeddingCacheOrder.append(cacheKey)
            if embeddingCacheOrder.count > maxEmbeddingCacheEntries,
               let evicted = embeddingCacheOrder.first {
                embeddingCache.removeValue(forKey: evicted)
                embeddingCacheOrder.removeFirst()
            }
            return normalized
        }
    }

    func reduceEmbeddingsIfNeeded(
        _ embeddings: [[Double]],
        contentHash: String,
        model: TopicEmbeddingModel,
        allowReduction: Bool
    ) -> TopicEmbeddingReductionResult {
        guard let first = embeddings.first else {
            return TopicEmbeddingReductionResult(
                vectors: [],
                applied: false,
                originalDimensions: nil,
                reducedDimensions: nil,
                explainedVariance: nil
            )
        }

        let originalDimensions = first.count
        guard allowReduction else {
            return TopicEmbeddingReductionResult(
                vectors: embeddings,
                applied: false,
                originalDimensions: originalDimensions,
                reducedDimensions: nil,
                explainedVariance: nil
            )
        }
        let targetDimensions = min(
            Self.targetPCADimensions,
            originalDimensions,
            max(1, embeddings.count - 1)
        )
        guard originalDimensions > Self.targetPCADimensions,
              embeddings.count >= Self.minimumPCASampleCount,
              targetDimensions < originalDimensions else {
            return TopicEmbeddingReductionResult(
                vectors: embeddings,
                applied: false,
                originalDimensions: originalDimensions,
                reducedDimensions: nil,
                explainedVariance: nil
            )
        }

        let cacheKey = [
            model.providerRevision,
            contentHash,
            "pca",
            "\(embeddings.count)",
            "\(originalDimensions)",
            "\(targetDimensions)"
        ].joined(separator: "::")
        if let cached = reductionCache[cacheKey] {
            touchReductionCacheKey(cacheKey)
            return cached
        }

        guard let centered = centeredMatrix(from: embeddings) else {
            let result = TopicEmbeddingReductionResult(
                vectors: embeddings,
                applied: false,
                originalDimensions: originalDimensions,
                reducedDimensions: nil,
                explainedVariance: nil
            )
            storeReductionResult(result, for: cacheKey)
            return result
        }

        let covariance = covarianceMatrix(from: centered)
        guard covariance.totalVariance > Self.zeroTolerance else {
            let result = TopicEmbeddingReductionResult(
                vectors: embeddings,
                applied: false,
                originalDimensions: originalDimensions,
                reducedDimensions: nil,
                explainedVariance: nil
            )
            storeReductionResult(result, for: cacheKey)
            return result
        }

        let eigenpairs = leadingEigenpairs(
            covarianceMatrix: covariance.matrix,
            dimension: centered.columnCount,
            targetDimensions: targetDimensions,
            totalVariance: covariance.totalVariance
        )
        let explainedVariance = eigenpairs.eigenvalues.reduce(0, +) / covariance.totalVariance
        let meetsComponentFloor = eigenpairs.eigenvectors.count >= min(Self.minimumPCAComponents, targetDimensions)
            || explainedVariance >= Self.targetExplainedVariance
        guard !eigenpairs.eigenvectors.isEmpty,
              meetsComponentFloor,
              explainedVariance >= Self.minimumExplainedVariance else {
            let result = TopicEmbeddingReductionResult(
                vectors: embeddings,
                applied: false,
                originalDimensions: originalDimensions,
                reducedDimensions: nil,
                explainedVariance: explainedVariance.isFinite ? explainedVariance : nil
            )
            storeReductionResult(result, for: cacheKey)
            return result
        }

        let reducedVectors = project(
            centered: centered,
            eigenvectors: eigenpairs.eigenvectors
        ).map(normalize)
        let result = TopicEmbeddingReductionResult(
            vectors: reducedVectors,
            applied: true,
            originalDimensions: originalDimensions,
            reducedDimensions: eigenpairs.eigenvectors.count,
            explainedVariance: explainedVariance
        )
        storeReductionResult(result, for: cacheKey)
        return result
    }

    func touchEmbeddingCacheKey(_ cacheKey: String) {
        embeddingCacheOrder.removeAll(where: { $0 == cacheKey })
        embeddingCacheOrder.append(cacheKey)
    }

    func touchReductionCacheKey(_ cacheKey: String) {
        reductionCacheOrder.removeAll(where: { $0 == cacheKey })
        reductionCacheOrder.append(cacheKey)
    }

    func storeReductionResult(_ result: TopicEmbeddingReductionResult, for cacheKey: String) {
        reductionCache[cacheKey] = result
        reductionCacheOrder.removeAll(where: { $0 == cacheKey })
        reductionCacheOrder.append(cacheKey)
        if reductionCacheOrder.count > maxReductionCacheEntries,
           let evicted = reductionCacheOrder.first {
            reductionCache.removeValue(forKey: evicted)
            reductionCacheOrder.removeFirst()
        }
    }

    fileprivate func centeredMatrix(from embeddings: [[Double]]) -> TopicCenteredEmbeddingMatrix? {
        guard let first = embeddings.first else { return nil }

        let rowCount = embeddings.count
        let columnCount = first.count
        guard columnCount > 0 else { return nil }

        var means = Array(repeating: 0.0, count: columnCount)
        for vector in embeddings {
            guard vector.count == columnCount else { return nil }
            for index in 0..<columnCount {
                means[index] += vector[index]
            }
        }

        let scale = 1.0 / Double(max(1, rowCount))
        means = means.map { $0 * scale }

        var flattened = Array(repeating: 0.0, count: rowCount * columnCount)
        for row in 0..<rowCount {
            for column in 0..<columnCount {
                flattened[(row * columnCount) + column] = embeddings[row][column] - means[column]
            }
        }

        return TopicCenteredEmbeddingMatrix(
            rowCount: rowCount,
            columnCount: columnCount,
            flattened: flattened
        )
    }

    fileprivate func covarianceMatrix(
        from centered: TopicCenteredEmbeddingMatrix
    ) -> (matrix: [Double], totalVariance: Double) {
        let denominator = Double(max(1, centered.rowCount - 1))
        var matrix = Array(
            repeating: 0.0,
            count: centered.columnCount * centered.columnCount
        )

        cblas_dgemm(
            CblasRowMajor,
            CblasTrans,
            CblasNoTrans,
            Int32(centered.columnCount),
            Int32(centered.columnCount),
            Int32(centered.rowCount),
            1.0 / denominator,
            centered.flattened,
            Int32(centered.columnCount),
            centered.flattened,
            Int32(centered.columnCount),
            0.0,
            &matrix,
            Int32(centered.columnCount)
        )

        var totalVariance = 0.0
        for diagonalIndex in 0..<centered.columnCount {
            totalVariance += matrix[(diagonalIndex * centered.columnCount) + diagonalIndex]
        }

        return (matrix, totalVariance)
    }

    func leadingEigenpairs(
        covarianceMatrix: [Double],
        dimension: Int,
        targetDimensions: Int,
        totalVariance: Double
    ) -> (eigenvectors: [[Double]], eigenvalues: [Double]) {
        guard totalVariance > Self.zeroTolerance else {
            return ([], [])
        }

        var eigenvectors: [[Double]] = []
        var eigenvalues: [Double] = []
        var cumulativeVariance = 0.0

        for componentIndex in 0..<targetDimensions {
            var vector = initialEigenvector(
                dimension: dimension,
                seed: componentIndex + 1
            )
            orthogonalize(&vector, against: eigenvectors)
            vector = normalized(vector)
            guard !vector.isEmpty else { break }

            for _ in 0..<Self.maxPowerIterations {
                var next = matrixVectorProduct(
                    covarianceMatrix,
                    dimension: dimension,
                    vector: vector
                )
                orthogonalize(&next, against: eigenvectors)
                next = normalized(next)
                guard !next.isEmpty else {
                    vector = []
                    break
                }

                let delta = zip(next, vector).reduce(0.0) { partialResult, pair in
                    max(partialResult, abs(pair.0 - pair.1))
                }
                vector = next
                if delta < Self.powerIterationTolerance {
                    break
                }
            }

            guard !vector.isEmpty else { break }

            let product = matrixVectorProduct(
                covarianceMatrix,
                dimension: dimension,
                vector: vector
            )
            let eigenvalue = max(0, dot(vector, product))
            guard eigenvalue > Self.zeroTolerance else { break }

            eigenvectors.append(vector)
            eigenvalues.append(eigenvalue)
            cumulativeVariance += eigenvalue

            if eigenvectors.count >= min(Self.minimumPCAComponents, targetDimensions),
               cumulativeVariance / totalVariance >= Self.targetExplainedVariance {
                break
            }
        }

        return (eigenvectors, eigenvalues)
    }

    func initialEigenvector(
        dimension: Int,
        seed: Int
    ) -> [Double] {
        (0..<dimension).map { index in
            sin(Double((seed * 31) + index + 1))
        }
    }

    func orthogonalize(
        _ vector: inout [Double],
        against basis: [[Double]]
    ) {
        guard !vector.isEmpty else { return }

        for basisVector in basis where basisVector.count == vector.count {
            let projection = dot(vector, basisVector)
            guard projection != 0 else { continue }
            for index in vector.indices {
                vector[index] -= basisVector[index] * projection
            }
        }
    }

    func normalized(_ vector: [Double]) -> [Double] {
        let norm = l2Norm(vector)
        guard norm > Self.zeroTolerance else { return [] }
        return vector.map { $0 / norm }
    }

    func l2Norm(_ vector: [Double]) -> Double {
        sqrt(dot(vector, vector))
    }

    func dot(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count else { return 0 }
        return zip(lhs, rhs).reduce(0.0) { partialResult, pair in
            partialResult + (pair.0 * pair.1)
        }
    }

    func matrixVectorProduct(
        _ matrix: [Double],
        dimension: Int,
        vector: [Double]
    ) -> [Double] {
        guard vector.count == dimension else {
            return Array(repeating: 0.0, count: dimension)
        }

        var result = Array(repeating: 0.0, count: dimension)
        cblas_dgemv(
            CblasRowMajor,
            CblasNoTrans,
            Int32(dimension),
            Int32(dimension),
            1.0,
            matrix,
            Int32(dimension),
            vector,
            1,
            0.0,
            &result,
            1
        )
        return result
    }

    fileprivate func project(
        centered: TopicCenteredEmbeddingMatrix,
        eigenvectors: [[Double]]
    ) -> [[Double]] {
        guard !eigenvectors.isEmpty else { return [] }

        let componentCount = eigenvectors.count
        var basisMatrix = Array(
            repeating: 0.0,
            count: centered.columnCount * componentCount
        )
        for componentIndex in 0..<componentCount {
            let eigenvector = eigenvectors[componentIndex]
            for rowIndex in 0..<min(centered.columnCount, eigenvector.count) {
                basisMatrix[(rowIndex * componentCount) + componentIndex] = eigenvector[rowIndex]
            }
        }

        var projected = Array(
            repeating: 0.0,
            count: centered.rowCount * componentCount
        )
        cblas_dgemm(
            CblasRowMajor,
            CblasNoTrans,
            CblasNoTrans,
            Int32(centered.rowCount),
            Int32(componentCount),
            Int32(centered.columnCount),
            1.0,
            centered.flattened,
            Int32(centered.columnCount),
            basisMatrix,
            Int32(componentCount),
            0.0,
            &projected,
            Int32(componentCount)
        )

        return (0..<centered.rowCount).map { rowIndex in
            let start = rowIndex * componentCount
            return Array(projected[start..<(start + componentCount)])
        }
    }
}
