import Foundation

extension NativeTopicEngine {
    func makeEmbeddings(
        for slices: [TopicTextSlice],
        cacheKey: String,
        model: TopicEmbeddingModel
    ) -> [[Double]] {
        let key = [
            cacheKey,
            model.manifest.modelID,
            model.manifest.version,
            model.providerLabel,
            "\(model.manifest.dimensions)"
        ].joined(separator: "::")
        if let cached = embeddingCache[key] {
            touchEmbeddingCacheKey(key)
            return cached
        }

        let vectors = slices.map { slice in
            let embedded = model.vector(for: slice.text) ?? model.vector(for: slice.tokens.joined(separator: " "))
            return normalize(embedded ?? [])
        }

        embeddingCache[key] = vectors
        embeddingCacheOrder.removeAll(where: { $0 == key })
        embeddingCacheOrder.append(key)
        if embeddingCacheOrder.count > maxEmbeddingCacheEntries, let evicted = embeddingCacheOrder.first {
            embeddingCache.removeValue(forKey: evicted)
            embeddingCacheOrder.removeFirst()
        }
        return vectors
    }

    func touchEmbeddingCacheKey(_ cacheKey: String) {
        embeddingCacheOrder.removeAll(where: { $0 == cacheKey })
        embeddingCacheOrder.append(cacheKey)
    }

    func reduceVectors(_ vectors: [[Double]]) -> [[Double]] {
        guard let dimension = vectors.first?.count, dimension > 0 else { return vectors }
        let targetDimension = min(64, dimension)
        guard dimension > targetDimension else { return vectors }

        var means = Array(repeating: 0.0, count: dimension)
        for vector in vectors {
            for index in 0..<dimension {
                means[index] += vector[index]
            }
        }
        let count = Double(max(1, vectors.count))
        for index in 0..<dimension {
            means[index] /= count
        }

        return vectors.map { vector in
            let centered = zip(vector, means).map { $0 - $1 }
            return normalize(Array(centered.prefix(targetDimension)))
        }
    }
}
