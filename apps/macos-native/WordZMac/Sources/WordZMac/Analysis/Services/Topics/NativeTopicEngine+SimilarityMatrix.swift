import Accelerate
import Foundation

extension NativeTopicEngine {
    func pairwiseSimilarityMatrix(for vectors: [[Double]]) -> [[Double]] {
        pairwiseSimilarityMatrix(for: vectors, lexicalContext: nil)
    }

    func pairwiseSimilarityMatrix(
        for vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> [[Double]] {
        guard !vectors.isEmpty else { return [] }

        if lexicalContext == nil,
           vectors.count >= runtimeTuning.topicSimilarityMatrixMultiplicationMinVectors,
           let matrix = acceleratedSimilarityMatrix(for: vectors) {
            return matrix
        }

        return scalarPairwiseSimilarityMatrix(
            for: vectors,
            lexicalContext: lexicalContext
        )
    }

    func scalarPairwiseSimilarityMatrix(
        for vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> [[Double]] {
        var matrix = Array(
            repeating: Array(repeating: 0.0, count: vectors.count),
            count: vectors.count
        )
        for lhs in vectors.indices {
            matrix[lhs][lhs] = 1
            for rhs in (lhs + 1)..<vectors.count {
                let similarity: Double
                if let lexicalContext {
                    similarity = exactHybridSimilarity(
                        lhsIndex: lhs,
                        rhsIndex: rhs,
                        vectors: vectors,
                        lexicalContext: lexicalContext
                    )
                } else {
                    similarity = cosineSimilarity(vectors[lhs], vectors[rhs])
                }
                matrix[lhs][rhs] = similarity
                matrix[rhs][lhs] = similarity
            }
        }
        return matrix
    }

    func acceleratedSimilarityMatrix(for vectors: [[Double]]) -> [[Double]]? {
        guard let dimensions = vectors.first?.count,
              dimensions > 0,
              vectors.allSatisfy({ $0.count == dimensions }) else {
            return nil
        }

        let rowCount = vectors.count
        let normalizedRows = normalizedFlattenedRows(
            for: vectors,
            dimensions: dimensions
        )
        var flattenedMatrix = Array(repeating: 0.0, count: rowCount * rowCount)

        normalizedRows.withUnsafeBufferPointer { rows in
            flattenedMatrix.withUnsafeMutableBufferPointer { output in
                guard let rowBaseAddress = rows.baseAddress,
                      let outputBaseAddress = output.baseAddress else {
                    return
                }
                cblas_dgemm(
                    CblasRowMajor,
                    CblasNoTrans,
                    CblasTrans,
                    Int32(rowCount),
                    Int32(rowCount),
                    Int32(dimensions),
                    1.0,
                    rowBaseAddress,
                    Int32(dimensions),
                    rowBaseAddress,
                    Int32(dimensions),
                    0.0,
                    outputBaseAddress,
                    Int32(rowCount)
                )
            }
        }

        var matrix: [[Double]] = []
        matrix.reserveCapacity(rowCount)
        for rowIndex in 0..<rowCount {
            let start = rowIndex * rowCount
            let end = start + rowCount
            var row = Array(flattenedMatrix[start..<end])
            row[rowIndex] = 1
            matrix.append(row)
        }
        return matrix
    }

    private func normalizedFlattenedRows(
        for vectors: [[Double]],
        dimensions: Int
    ) -> [Double] {
        var flattened: [Double] = []
        flattened.reserveCapacity(vectors.count * dimensions)
        for vector in vectors {
            let magnitude = cblas_dnrm2(Int32(dimensions), vector, 1)
            guard magnitude > 0 else {
                flattened.append(contentsOf: vector)
                continue
            }

            var scale = 1.0 / magnitude
            var normalized = Array(repeating: 0.0, count: dimensions)
            vDSP_vsmulD(
                vector,
                1,
                &scale,
                &normalized,
                1,
                vDSP_Length(dimensions)
            )
            flattened.append(contentsOf: normalized)
        }
        return flattened
    }
}
