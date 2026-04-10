import Foundation

extension EngineClient {
    func handleStdoutLine(_ line: String) async {
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
            startupTimeoutTask?.cancel()
            startupTimeoutTask = nil
            startupContinuation?.resume()
            startupContinuation = nil
        case .engineStartupError(let message):
            latestEngineError = message
            startupFailedMessage = message
            startupTimeoutTask?.cancel()
            startupTimeoutTask = nil
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

    func handleEngineErrorLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        latestEngineError = trimmed
    }

    func consumeStdoutData(_ data: Data) async {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        stdoutBuffer.append(chunk)
        while let newlineRange = stdoutBuffer.range(of: "\n") {
            let line = String(stdoutBuffer[..<newlineRange.lowerBound])
            stdoutBuffer.removeSubrange(..<newlineRange.upperBound)
            await handleStdoutLine(line)
        }
    }

    func consumeStderrData(_ data: Data) async {
        guard !data.isEmpty else { return }
        let chunk = String(decoding: data, as: UTF8.self)
        stderrBuffer.append(chunk)
        while let newlineRange = stderrBuffer.range(of: "\n") {
            let line = String(stderrBuffer[..<newlineRange.lowerBound])
            stderrBuffer.removeSubrange(..<newlineRange.upperBound)
            handleEngineErrorLine(line)
        }
    }
}
