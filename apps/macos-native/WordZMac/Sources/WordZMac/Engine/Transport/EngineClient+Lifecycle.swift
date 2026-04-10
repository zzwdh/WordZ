import Foundation
import Darwin

extension EngineClient {
    func start(userDataURL: URL? = nil) async throws {
        if isRunning { return }

        let repositoryRoot = try runtime.repositoryRoot()
        let nodeExecutableURL = try runtime.nodeExecutableURL()
        let engineURL = try runtime.engineEntryURL()
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

        let nextProcess = runtime.makeProcess()
        nextProcess.executableURL = nodeExecutableURL
        var arguments = [engineURL.path]
        let resolvedUserDataURL = userDataURL ?? runtime.defaultUserDataURL()
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

        do {
            try await waitForReady(timeoutNanoseconds: runtime.startupTimeoutNanoseconds)
        } catch {
            cleanupAfterStartupFailure(process: nextProcess, startupError: error)
            throw error
        }
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
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        hasReceivedReady = false
        startupFailedMessage = ""
        completePendingRequests(error: EngineClientError.engineNotStarted)
    }

    func getLatestEngineError() -> String {
        latestEngineError
    }

    func handleProcessTermination() async {
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
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        if let startupContinuation {
            let message = latestEngineError.isEmpty ? "本地引擎在准备完成前退出。" : latestEngineError
            startupContinuation.resume(throwing: EngineClientError.engineStartupFailed(message))
            self.startupContinuation = nil
        }
        completePendingRequests(error: EngineClientError.engineNotStarted)
    }

    func cleanupAfterStartupFailure(process failedProcess: EngineProcessControlling, startupError: Error) {
        failedProcess.terminationHandler = nil
        stdoutHandle?.readabilityHandler = nil
        stderrHandle?.readabilityHandler = nil
        stdinHandle?.closeFile()
        if failedProcess.isRunning {
            failedProcess.terminate()
            usleep(100_000)
            let pid = failedProcess.processIdentifier
            if failedProcess.isRunning, pid > 0 {
                _ = kill(pid, SIGKILL)
                usleep(50_000)
            }
        }
        process = nil
        stdinHandle = nil
        stdoutHandle = nil
        stderrHandle = nil
        stdoutBuffer = ""
        stderrBuffer = ""
        startupContinuation = nil
        startupTimeoutTask?.cancel()
        startupTimeoutTask = nil
        hasReceivedReady = false
        completePendingRequests(error: startupError)
    }

    func waitForReady(timeoutNanoseconds: UInt64 = 12_000_000_000) async throws {
        if hasReceivedReady { return }
        if !startupFailedMessage.isEmpty {
            throw EngineClientError.engineStartupFailed(startupFailedMessage)
        }

        return try await withCheckedThrowingContinuation { continuation in
            registerStartupContinuation(continuation, timeoutNanoseconds: timeoutNanoseconds)
        }
    }

    func registerStartupContinuation(
        _ continuation: CheckedContinuation<Void, Error>,
        timeoutNanoseconds: UInt64
    ) {
        if hasReceivedReady {
            continuation.resume()
            return
        }
        if !startupFailedMessage.isEmpty {
            continuation.resume(throwing: EngineClientError.engineStartupFailed(startupFailedMessage))
            return
        }
        startupTimeoutTask?.cancel()
        startupContinuation = continuation
        startupTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            await self?.resumeStartupContinuationForTimeout()
        }
    }

    func resumeStartupContinuationForTimeout() {
        guard let startupContinuation, !hasReceivedReady else { return }
        self.startupContinuation = nil
        startupTimeoutTask = nil
        startupContinuation.resume(
            throwing: EngineClientError.engineReadyTimeout(
                "本地引擎启动超时。请检查 Node.js、用户数据目录权限或查看启动错误详情。"
            )
        )
    }

    func completePendingRequests(error: Error) {
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
