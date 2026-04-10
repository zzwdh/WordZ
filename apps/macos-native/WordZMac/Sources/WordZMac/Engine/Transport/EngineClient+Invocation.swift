import Foundation

extension EngineClient {
    func invokeResult(method: String, params: JSONObject? = nil) async throws -> JSONObject {
        let data = try await invoke(method: method, params: params)
        return try EngineProtocolSupport.decodeInvokeResult(from: data)
    }

    func invoke(method: String, params: JSONObject? = nil, timeoutNanoseconds: UInt64 = 8_000_000_000) async throws -> Data {
        guard let stdinHandle else {
            throw EngineClientError.engineNotStarted
        }

        let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let requestData = try EngineProtocolSupport.makeRequestData(
            id: requestId,
            method: method,
            params: params
        )

        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { continuation in
                    Task {
                        await self?.registerPendingResponse(
                            continuation,
                            requestId: requestId,
                            stdinHandle: stdinHandle,
                            requestData: requestData
                        )
                    }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw EngineClientError.requestTimeout("本地引擎请求超时：\(method)")
            }

            do {
                guard let result = try await group.next() else {
                    throw EngineClientError.engineNotStarted
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                if let continuation = pendingResponses.removeValue(forKey: requestId) {
                    continuation.resume(throwing: error)
                }
                throw error
            }
        }
    }

    func runTask(_ params: JSONObject) async throws -> JSONObject {
        let startResult = try await invokeResult(method: EngineContracts.Method.analysisStartTask, params: params)
        let taskId = JSONFieldReader.string(startResult, key: "taskId")
        if taskId.isEmpty {
            throw EngineClientError.malformedResponse
        }

        let taskParamsData = try await withCheckedThrowingContinuation { continuation in
            taskWaiters[taskId] = continuation
        }

        return try EngineProtocolSupport.decodeTaskPayload(taskId: taskId, from: taskParamsData)
    }

    func registerPendingResponse(
        _ continuation: CheckedContinuation<Data, Error>,
        requestId: String,
        stdinHandle: FileHandle,
        requestData: Data
    ) {
        pendingResponses[requestId] = continuation
        do {
            var framedData = requestData
            framedData.append(0x0A)
            try stdinHandle.write(contentsOf: framedData)
        } catch {
            pendingResponses.removeValue(forKey: requestId)
            continuation.resume(throwing: error)
        }
    }
}
