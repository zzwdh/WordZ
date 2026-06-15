import Accelerate
import Foundation

extension NativeTopicEngine {
    func normalizedVectorMatrix(for vectors: [[Double]]) -> TopicNormalizedVectorMatrix? {
        guard let columnCount = vectors.first?.count, columnCount > 0 else { return nil }
        guard vectors.allSatisfy({ $0.count == columnCount }) else { return nil }

        var storage: [Double] = []
        storage.reserveCapacity(vectors.count * columnCount)
        for vector in vectors {
            storage.append(contentsOf: vector)
        }
        return TopicNormalizedVectorMatrix(
            rowCount: vectors.count,
            columnCount: columnCount,
            storage: storage
        )
    }

    func bestCentroidAssignments(
        for vectors: [[Double]],
        normalizedMatrix: TopicNormalizedVectorMatrix?,
        centroids: [[Double]]
    ) -> [(index: Int, similarity: Double)] {
        if let normalizedMatrix,
           let accelerated = acceleratedBestCentroidAssignments(
               matrix: normalizedMatrix,
               centroids: centroids
           ) {
            return accelerated
        }

        return vectors.map { vector in
            bestCentroidAssignment(for: vector, centroids: centroids)
        }
    }

    func acceleratedBestCentroidAssignments(
        matrix: TopicNormalizedVectorMatrix,
        centroids: [[Double]]
    ) -> [(index: Int, similarity: Double)]? {
        guard !centroids.isEmpty,
              centroids.allSatisfy({ $0.count == matrix.columnCount }) else {
            return nil
        }

        let clusterCount = centroids.count
        let centroidStorage = centroids.flatMap { $0 }
        var scores = Array(repeating: 0.0, count: matrix.rowCount * clusterCount)
        matrix.storage.withUnsafeBufferPointer { matrixPointer in
            centroidStorage.withUnsafeBufferPointer { centroidPointer in
                scores.withUnsafeMutableBufferPointer { scorePointer in
                    guard let matrixBaseAddress = matrixPointer.baseAddress,
                          let centroidBaseAddress = centroidPointer.baseAddress,
                          let scoreBaseAddress = scorePointer.baseAddress else {
                        return
                    }
                    cblas_dgemm(
                        CblasRowMajor,
                        CblasNoTrans,
                        CblasTrans,
                        Int32(matrix.rowCount),
                        Int32(clusterCount),
                        Int32(matrix.columnCount),
                        1.0,
                        matrixBaseAddress,
                        Int32(matrix.columnCount),
                        centroidBaseAddress,
                        Int32(matrix.columnCount),
                        0.0,
                        scoreBaseAddress,
                        Int32(clusterCount)
                    )
                }
            }
        }

        var assignments: [(index: Int, similarity: Double)] = []
        assignments.reserveCapacity(matrix.rowCount)
        for rowIndex in 0..<matrix.rowCount {
            let rowOffset = rowIndex * clusterCount
            var bestIndex = 0
            var bestSimilarity = -Double.infinity
            for clusterIndex in 0..<clusterCount {
                let similarity = scores[rowOffset + clusterIndex]
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                    bestIndex = clusterIndex
                }
            }
            assignments.append((bestIndex, max(-1, min(1, bestSimilarity))))
        }
        return assignments
    }
}
