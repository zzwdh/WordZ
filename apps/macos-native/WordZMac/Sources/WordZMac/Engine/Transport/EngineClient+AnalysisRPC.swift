import Foundation

extension EngineClient {
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
}
