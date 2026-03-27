import XCTest
@testable import WordZMac

final class EngineProtocolSupportTests: XCTestCase {
    func testMakeRequestDataBuildsJsonRpcEnvelope() throws {
        let data = try EngineProtocolSupport.makeRequestData(
            id: "req-1",
            method: EngineContracts.Method.appGetInfo,
            params: ["folderId": "all"]
        )

        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? JSONObject)
        XCTAssertEqual(object["jsonrpc"] as? String, EngineContracts.jsonRpcVersion)
        XCTAssertEqual(object["id"] as? String, "req-1")
        XCTAssertEqual(object["method"] as? String, EngineContracts.Method.appGetInfo)
        XCTAssertEqual((object["params"] as? JSONObject)?["folderId"] as? String, "all")
    }

    func testDecodeInvokeResultReturnsResultPayloadOnSuccess() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": "req-1",
            "result": [
                "success": true,
                "appInfo": ["name": "WordZ"]
            ]
        ])

        let result = try EngineProtocolSupport.decodeInvokeResult(from: data)

        XCTAssertEqual((result["appInfo"] as? JSONObject)?["name"] as? String, "WordZ")
    }

    func testDecodeInvokeResultThrowsRpcErrorForErrorPayload() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": "req-1",
            "error": [
                "message": "boom"
            ]
        ])

        do {
            _ = try EngineProtocolSupport.decodeInvokeResult(from: data)
            XCTFail("Expected rpc error")
        } catch let error as EngineClientError {
            guard case .rpc(let message) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(message, "boom")
        }
    }

    func testDecodeInvokeResultThrowsMalformedResponseForMissingResult() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": "req-1"
        ])

        XCTAssertThrowsError(try EngineProtocolSupport.decodeInvokeResult(from: data)) { error in
            guard case EngineClientError.malformedResponse = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testDecodeTaskPayloadWrapsTaskIdAroundResult() throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "result": [
                ["word": "alpha", "count": 3]
            ]
        ])

        let payload = try EngineProtocolSupport.decodeTaskPayload(taskId: "task-1", from: data)

        XCTAssertEqual(payload["taskId"] as? String, "task-1")
        XCTAssertEqual((payload["result"] as? [JSONObject])?.first?["word"] as? String, "alpha")
    }

    func testClassifyStdoutEventDetectsResponse() throws {
        let object: JSONObject = [
            "jsonrpc": EngineContracts.jsonRpcVersion,
            "id": "req-1",
            "result": ["success": true]
        ]

        let event = EngineProtocolSupport.classifyStdoutEvent(from: object)

        guard case .response(let id, let data) = event else {
            return XCTFail("Expected response event")
        }
        XCTAssertEqual(id, "req-1")
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? JSONObject)
        XCTAssertEqual((decoded["result"] as? JSONObject)?["success"] as? Bool, true)
    }

    func testClassifyStdoutEventDetectsTaskEventsAndIgnoresUnknownPayload() throws {
        let completed: JSONObject = [
            "method": EngineContracts.Event.taskCompleted,
            "params": [
                "taskId": "task-1",
                "result": [
                    ["word": "alpha"]
                ]
            ]
        ]
        let failed: JSONObject = [
            "method": EngineContracts.Event.taskFailed,
            "params": [
                "taskId": "task-2",
                "error": "bad task"
            ]
        ]
        let ignored: JSONObject = [
            "method": "unknown.event",
            "params": [
                "taskId": "task-3"
            ]
        ]

        let completedEvent = EngineProtocolSupport.classifyStdoutEvent(from: completed)
        guard case .taskCompleted(let taskId, let data) = completedEvent else {
            return XCTFail("Expected task completed event")
        }
        XCTAssertEqual(taskId, "task-1")
        let decodedParams = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? JSONObject)
        XCTAssertEqual((decodedParams["result"] as? [JSONObject])?.first?["word"] as? String, "alpha")

        let failedEvent = EngineProtocolSupport.classifyStdoutEvent(from: failed)
        guard case .taskFailed(let failedTaskId, let message) = failedEvent else {
            return XCTFail("Expected task failed event")
        }
        XCTAssertEqual(failedTaskId, "task-2")
        XCTAssertEqual(message, "bad task")

        XCTAssertEqual(EngineProtocolSupport.classifyStdoutEvent(from: ignored), .ignored)
    }
}
