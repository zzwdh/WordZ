import Foundation

@MainActor
struct WorkspaceDomainFactory {
    func makeSceneStore() -> WorkspaceSceneStore {
        WorkspaceSceneStore()
    }

    func makeSceneGraphStore() -> WorkspaceSceneGraphStore {
        WorkspaceSceneGraphStore()
    }

    func makeRootSceneBuilder() -> any RootContentSceneBuilding {
        RootContentSceneBuilder()
    }

    func makeSessionStore() -> WorkspaceSessionStore {
        WorkspaceSessionStore()
    }

    func makeTaskCenter() -> NativeTaskCenter {
        NativeTaskCenter()
    }

    func makeCoordinatorFactory() -> any WorkspaceCoordinatorBuilding {
        WorkspaceCoordinatorFactory()
    }

    func makeRuntimeDependencyFactory() -> any MainWorkspaceRuntimeDependencyBuilding {
        MainWorkspaceRuntimeDependencyFactory()
    }

    func makeWorkspacePresentation() -> WorkspacePresentationService {
        WorkspacePresentationService()
    }

    func makeWindowDocumentController() -> NativeWindowDocumentController {
        NativeWindowDocumentController()
    }
}
