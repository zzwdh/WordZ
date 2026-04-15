import Foundation

struct InFlightAnalysisValue: @unchecked Sendable {
    let rawValue: Any
}

extension NativeWorkspaceRepositoryCore {
    func cachedAnalysisResult<T: Sendable>(
        for key: NativeAnalysisResultCacheKey,
        compute: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        if let cached: T = analysisResultCache.value(for: key) {
            return cached
        }

        if let task = inFlightAnalysisTasks[key] {
            let result: T = try await resolveAnalysisTask(task, for: key)
            analysisResultCache.store(result, for: key)
            return result
        }

        let task = Task<Result<InFlightAnalysisValue, Error>, Never> {
            do {
                return .success(InFlightAnalysisValue(rawValue: try await compute()))
            } catch {
                return .failure(error)
            }
        }
        inFlightAnalysisTasks[key] = task
        defer { inFlightAnalysisTasks[key] = nil }

        let result: T = try await resolveAnalysisTask(task, for: key)
        analysisResultCache.store(result, for: key)
        return result
    }

    private func resolveAnalysisTask<T: Sendable>(
        _ task: Task<Result<InFlightAnalysisValue, Error>, Never>,
        for key: NativeAnalysisResultCacheKey
    ) async throws -> T {
        switch await task.value {
        case .success(let boxedValue):
            guard let result = boxedValue.rawValue as? T else {
                throw NSError(
                    domain: "WordZMac.NativeWorkspaceRepository",
                    code: 500,
                    userInfo: [
                        NSLocalizedDescriptionKey: "分析缓存结果类型不匹配：\(key.kind)"
                    ]
                )
            }
            return result
        case .failure(let error):
            throw error
        }
    }
}
