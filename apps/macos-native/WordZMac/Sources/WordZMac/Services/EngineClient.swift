import Foundation

enum EngineClientError: LocalizedError {
    case engineNotStarted
    case engineSpawnFailed(String)
    case engineStartupFailed(String)
    case engineReadyTimeout(String)
    case malformedResponse
    case rpc(String)
    case taskFailed(String)
    case requestTimeout(String)

    var errorDescription: String? {
        switch self {
        case .engineNotStarted:
            return "本地引擎尚未启动。"
        case .engineSpawnFailed(let message):
            return message
        case .engineStartupFailed(let message):
            return message
        case .engineReadyTimeout(let message):
            return message
        case .malformedResponse:
            return "引擎返回了无法解析的响应。"
        case .rpc(let message):
            return message
        case .taskFailed(let message):
            return message
        case .requestTimeout(let message):
            return message
        }
    }
}

actor EngineClient {
    private var process: Process?
    private var stdinHandle: FileHandle?
    private var stdoutHandle: FileHandle?
    private var stderrHandle: FileHandle?
    private var pendingResponses: [String: CheckedContinuation<Data, Error>] = [:]
    private var taskWaiters: [String: CheckedContinuation<Data, Error>] = [:]
    private var latestEngineError = ""
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var startupContinuation: CheckedContinuation<Void, Error>?
    private var hasReceivedReady = false
    private var startupFailedMessage = ""

    var isRunning: Bool {
        process?.isRunning == true && stdinHandle != nil
    }

    func start(userDataURL: URL? = nil) async throws {
        if isRunning { return }

        let repositoryRoot = try EnginePaths.repositoryRoot()
        let nodeExecutableURL = try EnginePaths.nodeExecutableURL()
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
        nextProcess.executableURL = nodeExecutableURL
        var arguments = [engineURL.path]
        let resolvedUserDataURL = userDataURL ?? EnginePaths.defaultUserDataURL()
        arguments.append("--user-data-dir=\(resolvedUserDataURL.path)")
        nextProcess.arguments = arguments
        nextProcess.standardOutput = stdoutPipe
        nextProcess.standardError = stderrPipe
        nextProcess.standardInput = stdinPipe
        nextProcess.currentDirectoryURL = repositoryRoot

        do {
            try nextProcess.run()
        } catch {
            throw EngineClientError.engineSpawnFailed("无法启动本地引擎进程：\(error.localizedDescription)")
        }

        process = nextProcess
        stdinHandle = stdinPipe.fileHandleForWriting
        stdoutHandle = stdoutPipe.fileHandleForReading
        stderrHandle = stderrPipe.fileHandleForReading
        stdoutBuffer = ""
        stderrBuffer = ""
        latestEngineError = ""
        startupFailedMessage = ""
        hasReceivedReady = false

        stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { await self?.consumeStdoutData(data) }
        }

        stderrPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { await self?.consumeStderrData(data) }
        }

        nextProcess.terminationHandler = { [weak self] _ in
            Task { await self?.handleProcessTermination() }
        }

        try await waitForReady()
    }

    func stop() async {
        _ = try? await invoke(method: EngineContracts.Method.engineShutdown)
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        stdinHandle?.closeFile()
        process?.terminate()
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
        stdoutBuffer = ""
        stderrBuffer = ""
        startupContinuation = nil
        hasReceivedReady = false
        startupFailedMessage = ""
        completePendingRequests(error: EngineClientError.engineNotStarted)
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

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryImportPaths,
            params: [
                "paths": paths,
                "folderId": folderId,
                "preserveHierarchy": preserveHierarchy
            ]
        )
        return LibraryImportResult(json: result)
    }

    func fetchWorkspaceState() async throws -> WorkspaceSnapshotSummary {
        let result = try await invokeResult(method: EngineContracts.Method.workspaceGetState)
        return WorkspaceSnapshotSummary(json: JSONFieldReader.dictionary(result, key: "snapshot"))
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.workspaceSaveState,
            params: ["snapshot": draft.asJSONObject()]
        )
    }

    func fetchUISettings() async throws -> UISettingsSnapshot {
        let result = try await invokeResult(method: EngineContracts.Method.workspaceGetUiSettings)
        return UISettingsSnapshot(json: JSONFieldReader.dictionary(result, key: "settings"))
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.workspaceSaveUiSettings,
            params: ["settings": snapshot.asJSONObject()]
        )
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryOpenSaved,
            params: ["corpusId": corpusId]
        )
        return OpenedCorpus(json: result)
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRenameCorpus,
            params: [
                "corpusId": corpusId,
                "newName": newName
            ]
        )
        return LibraryCorpusItem(json: JSONFieldReader.dictionary(result, key: "item"))
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryMoveCorpus,
            params: [
                "corpusId": corpusId,
                "targetFolderId": targetFolderId
            ]
        )
        return LibraryCorpusItem(json: JSONFieldReader.dictionary(result, key: "item"))
    }

    func deleteCorpus(corpusId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryDeleteCorpus,
            params: ["corpusId": corpusId]
        )
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryCreateFolder,
            params: ["folderName": name]
        )
        return LibraryFolderItem(json: JSONFieldReader.dictionary(result, key: "folder"))
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRenameFolder,
            params: [
                "folderId": folderId,
                "newName": newName
            ]
        )
        return LibraryFolderItem(json: JSONFieldReader.dictionary(result, key: "folder"))
    }

    func deleteFolder(folderId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryDeleteFolder,
            params: ["folderId": folderId]
        )
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        let result = try await invokeResult(method: EngineContracts.Method.libraryListRecycleBin)
        return RecycleBinSnapshot(json: result)
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryRestoreRecycleEntry,
            params: ["recycleEntryId": recycleEntryId]
        )
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        _ = try await invokeResult(
            method: EngineContracts.Method.libraryPurgeRecycleEntry,
            params: ["recycleEntryId": recycleEntryId]
        )
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryBackup,
            params: ["destinationPath": destinationPath]
        )
        return LibraryBackupSummary(json: result)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        let result = try await invokeResult(
            method: EngineContracts.Method.libraryRestore,
            params: ["sourcePath": sourcePath]
        )
        return LibraryRestoreSummary(json: result)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        let result = try await invokeResult(method: EngineContracts.Method.libraryRepair)
        return LibraryRepairSummary(json: result)
    }

    func runStats(text: String) async throws -> StatsResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.stats,
            "payload": ["text": text]
        ]
        let params = try await runTask(taskParams)
        return StatsResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.compare,
            "payload": ["comparisonEntries": comparisonEntries.map { $0.asJSONObject() }]
        ]
        let params = try await runTask(taskParams)
        return CompareResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.chiSquare,
            "payload": [
                "a": a,
                "b": b,
                "c": c,
                "d": d,
                "yates": yates
            ]
        ]
        let params = try await runTask(taskParams)
        return ChiSquareResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.ngram,
            "payload": [
                "text": text,
                "n": n
            ]
        ]
        let params = try await runTask(taskParams)
        return NgramResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.kwic,
            "payload": [
                "text": text,
                "keyword": keyword,
                "leftWindowSize": leftWindow,
                "rightWindowSize": rightWindow,
                "searchOptions": searchOptions.asJSONObject()
            ]
        ]
        let params = try await runTask(taskParams)
        return KWICResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.collocate,
            "payload": [
                "text": text,
                "keyword": keyword,
                "leftWindowSize": leftWindow,
                "rightWindowSize": rightWindow,
                "minFreq": minFreq,
                "searchOptions": searchOptions.asJSONObject()
            ]
        ]
        let params = try await runTask(taskParams)
        return CollocateResult(items: JSONFieldReader.array(params, key: "result"))
    }

    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.wordCloud,
            "payload": [
                "text": text,
                "limit": limit
            ]
        ]
        let params = try await runTask(taskParams)
        return WordCloudResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    func runLocator(
        text: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) async throws -> LocatorResult {
        let taskParams: JSONObject = [
            "taskType": EngineContracts.TaskType.locator,
            "payload": [
                "text": text,
                "sentenceId": sentenceId,
                "nodeIndex": nodeIndex,
                "leftWindowSize": leftWindow,
                "rightWindowSize": rightWindow
            ]
        ]
        let params = try await runTask(taskParams)
        return LocatorResult(json: JSONFieldReader.dictionary(params, key: "result"))
    }

    private func invokeResult(method: String, params: JSONObject? = nil) async throws -> JSONObject {
        let data = try await invoke(method: method, params: params)
        return try EngineProtocolSupport.decodeInvokeResult(from: data)
    }

    private func invoke(method: String, params: JSONObject? = nil, timeoutNanoseconds: UInt64 = 8_000_000_000) async throws -> Data {
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
                    Task { await self?.registerPendingResponse(continuation, requestId: requestId, stdinHandle: stdinHandle, requestData: requestData) }
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

    private func runTask(_ params: JSONObject) async throws -> JSONObject {
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

    private func handleStdoutLine(_ line: String) async {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject else { return }

        switch EngineProtocolSupport.classifyStdoutEvent(from: object) {
        case .response(let responseId, let responseData):
            if let continuation = pendingResponses.removeValue(forKey: responseId) {
                continuation.resume(returning: responseData)
            }
        case .engineReady:
            hasReceivedReady = true
            startupContinuation?.resume()
            startupContinuation = nil
        case .engineStartupError(let message):
            latestEngineError = message
            startupFailedMessage = message
            startupContinuation?.resume(throwing: EngineClientError.engineStartupFailed(message))
            startupContinuation = nil
        case .taskCompleted(let taskId, let paramsData):
            guard let continuation = taskWaiters.removeValue(forKey: taskId) else { return }
            continuation.resume(returning: paramsData)
        case .taskFailed(let taskId, let message):
            guard let continuation = taskWaiters.removeValue(forKey: taskId) else { return }
            continuation.resume(throwing: EngineClientError.taskFailed(message))
        case .ignored:
            break
        }
    }

    private func handleEngineErrorLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        latestEngineError = trimmed
    }

    private func consumeStdoutData(_ data: Data) async {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        stdoutBuffer.append(chunk)
        while let newlineRange = stdoutBuffer.range(of: "\n") {
            let line = String(stdoutBuffer[..<newlineRange.lowerBound])
            stdoutBuffer.removeSubrange(..<newlineRange.upperBound)
            await handleStdoutLine(line)
        }
    }

    private func consumeStderrData(_ data: Data) async {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        stderrBuffer.append(chunk)
        while let newlineRange = stderrBuffer.range(of: "\n") {
            let line = String(stderrBuffer[..<newlineRange.lowerBound])
            stderrBuffer.removeSubrange(..<newlineRange.upperBound)
            handleEngineErrorLine(line)
        }
    }

    private func handleProcessTermination() async {
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        if !stdoutBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await handleStdoutLine(stdoutBuffer)
        }
        if !stderrBuffer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            handleEngineErrorLine(stderrBuffer)
        }
        stdoutBuffer = ""
        stderrBuffer = ""
        if let startupContinuation {
            let message = latestEngineError.isEmpty ? "本地引擎在准备完成前退出。" : latestEngineError
            startupContinuation.resume(throwing: EngineClientError.engineStartupFailed(message))
            self.startupContinuation = nil
        }
        completePendingRequests(error: EngineClientError.engineNotStarted)
    }

    private func waitForReady(timeoutNanoseconds: UInt64 = 12_000_000_000) async throws {
        if hasReceivedReady { return }
        if !startupFailedMessage.isEmpty {
            throw EngineClientError.engineStartupFailed(startupFailedMessage)
        }

        return try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                try await withCheckedThrowingContinuation { continuation in
                    Task { await self?.registerStartupContinuation(continuation) }
                }
            }

            group.addTask {
                try await Task.sleep(nanoseconds: timeoutNanoseconds)
                throw EngineClientError.engineReadyTimeout("本地引擎启动超时。请检查 Node.js、用户数据目录权限或查看启动错误详情。")
            }

            do {
                guard let result = try await group.next() else {
                    throw EngineClientError.engineNotStarted
                }
                group.cancelAll()
                return result
            } catch {
                group.cancelAll()
                startupContinuation = nil
                throw error
            }
        }
    }

    private func registerStartupContinuation(_ continuation: CheckedContinuation<Void, Error>) {
        if hasReceivedReady {
            continuation.resume()
            return
        }
        if !startupFailedMessage.isEmpty {
            continuation.resume(throwing: EngineClientError.engineStartupFailed(startupFailedMessage))
            return
        }
        startupContinuation = continuation
    }

    private func registerPendingResponse(
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
