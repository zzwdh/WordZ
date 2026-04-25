import Foundation

package enum EngineStdoutEvent: Equatable {
    case response(id: String, data: Data)
    case engineReady
    case engineStartupError(message: String)
    case taskCompleted(taskId: String, data: Data)
    case taskFailed(taskId: String, message: String)
    case ignored
}

package enum EngineProtocolSupport {
    package static func makeRequestData(id: String, method: String, params: JSONObject? = nil) throws -> Data {
        let payload: JSONObject = [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": id,
            "method": method,
            "params": params ?? [:]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    package static func decodeInvokeResult(from data: Data) throws -> JSONObject {
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

    package static func decodeTaskPayload(taskId: String, from data: Data) throws -> JSONObject {
        guard let taskParams = try JSONSerialization.jsonObject(with: data) as? JSONObject else {
            throw EngineClientError.malformedResponse
        }

        if taskParams["result"] != nil {
            return [
                "taskId": taskId,
                "result": taskParams["result"] as Any
            ]
        }

        if let errorMessage = taskParams["error"] as? String {
            throw EngineClientError.taskFailed(errorMessage)
        }

        throw EngineClientError.malformedResponse
    }

    package static func classifyStdoutEvent(from object: JSONObject) -> EngineStdoutEvent {
        if let responseId = object["id"] as? String,
           let data = try? JSONSerialization.data(withJSONObject: object) {
            return .response(id: responseId, data: data)
        }

        guard let method = object["method"] as? String else { return .ignored }
        let params = object["params"] as? JSONObject ?? [:]

        switch method {
        case EngineContracts.Event.engineReady:
            return .engineReady
        case EngineContracts.Event.engineStartupError:
            let message = JSONFieldReader.string(params, key: "error", fallback: "引擎启动失败")
            return .engineStartupError(message: message)
        case EngineContracts.Event.taskCompleted:
            let taskId = JSONFieldReader.string(params, key: "taskId")
            guard !taskId.isEmpty else { return .ignored }
            guard let paramsData = try? JSONSerialization.data(withJSONObject: params) else {
                return .taskFailed(taskId: taskId, message: EngineClientError.malformedResponse.localizedDescription)
            }
            return .taskCompleted(taskId: taskId, data: paramsData)
        case EngineContracts.Event.taskFailed, EngineContracts.Event.taskCancelled:
            let taskId = JSONFieldReader.string(params, key: "taskId")
            guard !taskId.isEmpty else { return .ignored }
            let message = JSONFieldReader.string(params, key: "error", fallback: "任务失败")
            return .taskFailed(taskId: taskId, message: message)
        default:
            return .ignored
        }
    }
}
