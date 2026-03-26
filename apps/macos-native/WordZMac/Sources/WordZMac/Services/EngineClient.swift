import Foundation

enum EngineClientError: LocalizedError {
    case engineNotStarted
    case malformedResponse
    case rpc(String)
    case taskFailed(String)

    var errorDescription: String? {
        switch self {
        case .engineNotStarted:
            return "本地引擎尚未启动。"
        case .malformedResponse:
            return "引擎返回了无法解析的响应。"
        case .rpc(let message):
            return message
        case .taskFailed(let message):
            return message
        }
    }
}

actor EngineClient {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutTask: Task<Void, Never>?
    private var stderrTask: Task<Void, Never>?
    private var pendingResponses: [String: CheckedContinuation<Data, Error>] = [:]
    private var taskWaiters: [String: CheckedContinuation<Data, Error>] = [:]
    private var latestEngineError = ""

    var isRunning: Bool {
        process?.isRunning == true && stdinHandle != nil
    }

    func start(userDataURL: URL? = nil) async throws {
        if isRunning { return }

        let engineURL = try EnginePaths.engineEntryURL()
        guard FileManager.default.fileExists(atPath: engineURL.path) else {
            throw NSError(
                domain: "WordZMac.EngineClient",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "未找到 JS sidecar 入口：\(engineURL.path)"]
            )
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdinPipe = Pipe()

        let nextProcess = Process()
        nextProcess.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        var arguments = ["node", engineURL.path]
        let resolvedUserDataURL = userDataURL ?? EnginePaths.defaultUserDataURL()
        arguments.append("--user-data-dir=\(resolvedUserDataURL.path)")
        nextProcess.arguments = arguments
        nextProcess.standardOutput = stdoutPipe
        nextProcess.standardError = stderrPipe
        nextProcess.standardInput = stdinPipe

        try nextProcess.run()

        process = nextProcess
        stdinHandle = stdinPipe.fileHandleForWriting

        stdoutTask = Task.detached { [weak self] in
            guard let self else { return }
            do {
                for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                    await self.handleStdoutLine(String(line))
                }
                await self.completePendingRequests(error: EngineClientError.engineNotStarted)
            } catch {
                await self.completePendingRequests(error: error)
            }
        }

        stderrTask = Task.detached { [weak self] in
            guard let self else { return }
            do {
                for try await line in stderrPipe.fileHandleForReading.bytes.lines {
                    await self.handleEngineErrorLine(String(line))
                }
            } catch {
                await self.handleEngineErrorLine(error.localizedDescription)
            }
        }
    }

    func stop() async {
        _ = try? await invoke(method: EngineContracts.Method.engineShutdown)
        stdinHandle?.closeFile()
        process?.terminate()
        process = nil
        stdinHandle = nil
        stdoutTask?.cancel()
        stderrTask?.cancel()
        stdoutTask = nil
        stderrTask = nil
        await completePendingRequests(error: EngineClientError.engineNotStarted)
    }

    func getLatestEngineError() -> String {
        latestEngineError
    }

    func fetchAppInfo() async throws -> AppInfoSummary {
        let result = try await invokeResult(method: EngineContracts.Method.appGetInfo)
        return AppInfoSummary(json: JSONFieldReader.dictionary(result, key: "appInfo"))
    }

    func listLibrary(folderId: String = "all") async throws -> LibrarySnapshot {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryList,
            params: ["folderId": folderId]
        )
        return LibrarySnapshot(json: result)
    }

    func fetchWorkspaceState() async throws -> WorkspaceSnapshotSummary {
        let result = try await invokeResult(method: EngineContracts.Method.workspaceGetState)
        return WorkspaceSnapshotSummary(json: JSONFieldReader.dictionary(result, key: "snapshot"))
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryOpenSaved,
            params: ["corpusId": corpusId]
        )
        return OpenedCorpus(json: result)
    }

    func runStats(text: String) async throws -> StatsResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.stats,
            "payload": ["text": text]
        ]
        let params = try await runTask(taskParams)
        return StatsResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runKWIC(text: String, keyword: String, leftWindow: Int, rightWindow: Int) async throws -> KWICResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.kwic,
            "payload": [
                "text": text,
                "keyword": keyword,
                "leftWindowSize": leftWindow,
                "rightWindowSize": rightWindow,
                "searchOptions": [
                    "words": true,
                    "caseSensitive": false,
                    "regex": false
                ]
            ]
        ]
        let params = try await runTask(taskParams)
        return KWICResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    private func invokeResult(method: String, params: JSONObject? = nil) async throws -> JSONObject {
        let data = try await invoke(method: method, params: params)
        guard let payload = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw EngineClientError.malformedResponse
        }
        if let error = payload["error"] as? JSONObject {
            let message = JSONFieldReader.string(error, key: "message", fallback: "调用失败")
            throw EngineClientError.rpc(message)
        }
        guard let result = payload["result"] as? JSONObject else {
            throw EngineClientError.malformedResponse
        }
        if JSONFieldReader.bool(result, key: "success", fallback: true) == false {
            throw EngineClientError.rpc(JSONFieldReader.string(result, key: "message", fallback: "引擎返回失败"))
        }
        return result
    }

    private func invoke(method: String, params: JSONObject? = nil) async throws -> Data {
        guard let stdinHandle else {
            throw EngineClientError.engineNotStarted
        }

        let requestId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        let payload: JSONObject = [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": requestId,
            "method": method,
            "params": params ?? [:]
        ]
        let requestData = try JSONSerialization.data(withJSONObject: payload)

        return try await withCheckedThrowingContinuation { continuation in
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

    private func runTask(_ params: JSONObject) async throws -> JSONObject {
        let startResult = try await invokeResult(method: EngineContracts.Method.analysisStartTask, params: params)
        let taskId = JSONFieldReader.string(startResult, key: "taskId")
        if taskId.isEmpty {
            throw EngineClientError.malformedResponse
        }

        let taskParamsData = try await withCheckedThrowingContinuation { continuation in
            taskWaiters[taskId] = continuation
        }

        guard let taskParams = try JSONSerialization.jsonObject(with: taskParamsData) as? JSONObject else {
            throw EngineClientError.malformedResponse
        }

        if let result = taskParams["result"] as? JSONObject {
            return [
                "taskId": taskId,
                "result": result
            ]
        }

        if let errorMessage = taskParams["error"] as? String {
            throw EngineClientError.taskFailed(errorMessage)
        }

        throw EngineClientError.malformedResponse
    }

    private func handleStdoutLine(_ line: String) async {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject else { return }

        if let responseId = object["id"] as? String, let continuation = pendingResponses.removeValue(forKey: responseId) {
            continuation.resume(returning: data)
            return
        }

        guard let method = object["method"] as? String else { return }
        let params = object["params"] as? JSONObject ?? [:]
        let taskId = JSONFieldReader.string(params, key: "taskId")
        guard !taskId.isEmpty, let continuation = taskWaiters.removeValue(forKey: taskId) else { return }

        switch method {
        case EngineContracts.Event.taskCompleted:
            if let paramsData = try? JSONSerialization.data(withJSONObject: params) {
                continuation.resume(returning: paramsData)
            } else {
                continuation.resume(throwing: EngineClientError.malformedResponse)
            }
        case EngineContracts.Event.taskFailed, EngineContracts.Event.taskCancelled:
            let message = JSONFieldReader.string(params, key: "error", fallback: "任务失败")
            continuation.resume(throwing: EngineClientError.taskFailed(message))
        default:
            break
        }
    }

    private func handleEngineErrorLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        latestEngineError = trimmed
    }

    private func completePendingRequests(error: Error) {
        let pending = pendingResponses
        pendingResponses.removeAll()
        for (_, continuation) in pending {
            continuation.resume(throwing: error)
        }

        let waiters = taskWaiters
        taskWaiters.removeAll()
        for (_, continuation) in waiters {
            continuation.resume(throwing: error)
        }
    }
}
