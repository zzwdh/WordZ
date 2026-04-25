import Foundation

package protocol EngineProcessControlling: AnyObject {
    var executableURL: URL? { get set }
    var arguments: [String]? { get set }
    var standardOutput: Any? { get set }
    var standardError: Any? { get set }
    var standardInput: Any? { get set }
    var currentDirectoryURL: URL? { get set }
    var terminationHandler: ((EngineProcessControlling) -> Void)? { get set }
    var isRunning: Bool { get }
    var processIdentifier: Int32 { get }

    func run() throws
    func terminate()
}

final class LiveEngineProcess: EngineProcessControlling, @unchecked Sendable {
    private let process = Process()

    var executableURL: URL? {
        get { process.executableURL }
        set { process.executableURL = newValue }
    }

    var arguments: [String]? {
        get { process.arguments }
        set { process.arguments = newValue }
    }

    var standardOutput: Any? {
        get { process.standardOutput }
        set { process.standardOutput = newValue }
    }

    var standardError: Any? {
        get { process.standardError }
        set { process.standardError = newValue }
    }

    var standardInput: Any? {
        get { process.standardInput }
        set { process.standardInput = newValue }
    }

    var currentDirectoryURL: URL? {
        get { process.currentDirectoryURL }
        set { process.currentDirectoryURL = newValue }
    }

    var terminationHandler: ((EngineProcessControlling) -> Void)? {
        didSet {
            process.terminationHandler = { [weak self] _ in
                guard let self else { return }
                self.terminationHandler?(self)
            }
        }
    }

    var isRunning: Bool {
        process.isRunning
    }

    var processIdentifier: Int32 {
        process.processIdentifier
    }

    func run() throws {
        try process.run()
    }

    func terminate() {
        process.terminate()
    }
}

package struct EngineClientRuntime: Sendable {
    package var repositoryRoot: @Sendable () throws -> URL
    package var nodeExecutableURL: @Sendable () throws -> URL
    package var engineEntryURL: @Sendable () throws -> URL
    package var defaultUserDataURL: @Sendable () -> URL
    package var makeProcess: @Sendable () -> EngineProcessControlling
    package var startupTimeoutNanoseconds: UInt64

    package init(
        repositoryRoot: @escaping @Sendable () throws -> URL,
        nodeExecutableURL: @escaping @Sendable () throws -> URL,
        engineEntryURL: @escaping @Sendable () throws -> URL,
        defaultUserDataURL: @escaping @Sendable () -> URL,
        makeProcess: @escaping @Sendable () -> EngineProcessControlling,
        startupTimeoutNanoseconds: UInt64
    ) {
        self.repositoryRoot = repositoryRoot
        self.nodeExecutableURL = nodeExecutableURL
        self.engineEntryURL = engineEntryURL
        self.defaultUserDataURL = defaultUserDataURL
        self.makeProcess = makeProcess
        self.startupTimeoutNanoseconds = startupTimeoutNanoseconds
    }

    package static let live = EngineClientRuntime(
        repositoryRoot: { try EnginePaths.repositoryRoot() },
        nodeExecutableURL: { try EnginePaths.nodeExecutableURL() },
        engineEntryURL: { try EnginePaths.engineEntryURL() },
        defaultUserDataURL: { EnginePaths.defaultUserDataURL() },
        makeProcess: { LiveEngineProcess() },
        startupTimeoutNanoseconds: 12_000_000_000
    )
}

package struct EngineTransportStateSnapshot: Sendable {
    package let hasProcess: Bool
    package let hasStdinHandle: Bool
    package let hasStdoutHandle: Bool
    package let hasStderrHandle: Bool
}

package enum EngineClientError: LocalizedError {
    case engineNotStarted
    case engineSpawnFailed(String)
    case engineStartupFailed(String)
    case engineReadyTimeout(String)
    case malformedResponse
    case rpc(String)
    case taskFailed(String)
    case requestTimeout(String)

    package var errorDescription: String? {
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

package actor EngineClient {
    // Stored state stays on the actor shell so transport extensions share one source of truth.
    let runtime: EngineClientRuntime
    var process: EngineProcessControlling?
    var stdinHandle: FileHandle?
    var stdoutHandle: FileHandle?
    var stderrHandle: FileHandle?
    var pendingResponses: [String: CheckedContinuation<Data, Error>] = [:]
    var taskWaiters: [String: CheckedContinuation<Data, Error>] = [:]
    var latestEngineError = ""
    var stdoutBuffer = ""
    var stderrBuffer = ""
    var startupContinuation: CheckedContinuation<Void, Error>?
    var startupTimeoutTask: Task<Void, Never>?
    var hasReceivedReady = false
    var startupFailedMessage = ""

    package init(runtime: EngineClientRuntime = .live) {
        self.runtime = runtime
    }

    package var isRunning: Bool {
        process?.isRunning == true && stdinHandle != nil
    }

    package func transportStateSnapshot() -> EngineTransportStateSnapshot {
        EngineTransportStateSnapshot(
            hasProcess: process != nil,
            hasStdinHandle: stdinHandle != nil,
            hasStdoutHandle: stdoutHandle != nil,
            hasStderrHandle: stderrHandle != nil
        )
    }
}
