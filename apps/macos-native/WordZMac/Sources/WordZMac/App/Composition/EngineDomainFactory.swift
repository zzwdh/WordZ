import Foundation

@MainActor
struct EngineDomainFactory {
    func makeEngineClient() -> EngineClient {
        EngineClient()
    }

    func makeRepository() -> any WorkspaceRepository {
        EngineWorkspaceRepository(engineClient: makeEngineClient())
    }
}
