import Foundation

actor WorkspaceSessionActor {
    private var requestSequences: [WorkspaceRuntimeTaskKey: UInt64] = [:]

    func beginRequest(for key: WorkspaceRuntimeTaskKey) -> WorkspaceRequestToken {
        let nextSequence = (requestSequences[key] ?? 0) &+ 1
        requestSequences[key] = nextSequence
        return WorkspaceRequestToken(key: key, sequence: nextSequence)
    }

    func isCurrent(_ token: WorkspaceRequestToken) -> Bool {
        requestSequences[token.key] == token.sequence
    }
}
