import XCTest
@testable import WordZWorkspaceCore

final class EngineClientLifecycleTests: XCTestCase {
    func testStartResetsProcessStateWhenReadyTimesOut() async throws {
        let rootURL = temporaryDirectory(named: "wordz-engine-timeout")
        let engineURL = rootURL.appendingPathComponent("fake-engine.mjs")
        let userDataURL = rootURL.appendingPathComponent("userdata", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "// fake engine entry".write(to: engineURL, atomically: true, encoding: .utf8)

        let process = FakeTimeoutProcess()
        let client = EngineClient(runtime: EngineClientRuntime(
            repositoryRoot: { rootURL },
            nodeExecutableURL: { URL(fileURLWithPath: "/usr/bin/env") },
            engineEntryURL: { engineURL },
            defaultUserDataURL: { userDataURL },
            makeProcess: { process },
            startupTimeoutNanoseconds: 50_000_000
        ))

        do {
            try await client.start(userDataURL: userDataURL)
            XCTFail("Expected engine ready timeout")
        } catch let error as EngineClientError {
            guard case .engineReadyTimeout = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let isRunning = await client.isRunning
        let state = await client.transportStateSnapshot()

        XCTAssertTrue(process.didRun)
        XCTAssertTrue(process.didTerminate)
        XCTAssertFalse(process.isRunning)
        XCTAssertFalse(isRunning)
        XCTAssertFalse(state.hasProcess)
        XCTAssertFalse(state.hasStdinHandle)
        XCTAssertFalse(state.hasStdoutHandle)
        XCTAssertFalse(state.hasStderrHandle)
    }

    private func temporaryDirectory(named prefix: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }
}

private final class FakeTimeoutProcess: EngineProcessControlling, @unchecked Sendable {
    var didRun = false
    var didTerminate = false
    var executableURL: URL?
    var arguments: [String]?
    var standardOutput: Any?
    var standardError: Any?
    var standardInput: Any?
    var currentDirectoryURL: URL?
    var terminationHandler: ((EngineProcessControlling) -> Void)?
    private var runningState = false

    var isRunning: Bool {
        runningState
    }

    var processIdentifier: Int32 {
        4242
    }

    func run() throws {
        didRun = true
        runningState = true
    }

    func terminate() {
        didTerminate = true
        runningState = false
    }
}
