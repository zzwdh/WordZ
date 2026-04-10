import Foundation

@MainActor
final class WorkspaceSceneGraphStore: ObservableObject {
    @Published private(set) var graph = WorkspaceSceneGraph.empty
    private(set) var graphRevision = 0
    private let resultNodeBuilderFactory: any WorkspaceResultSceneNodeBuildingFactory

    init(
        resultNodeBuilderFactory: any WorkspaceResultSceneNodeBuildingFactory = DefaultWorkspaceResultSceneNodeBuilderFactory()
    ) {
        self.resultNodeBuilderFactory = resultNodeBuilderFactory
    }

    func replaceGraph(with graph: WorkspaceSceneGraph) {
        guard self.graph != graph else { return }
        applyGraph(graph)
    }

    func makeResultNodeBuilder(languageMode: AppLanguageMode) -> any WorkspaceResultSceneNodeBuilding {
        resultNodeBuilderFactory.make(languageMode: languageMode)
    }

    func applyGraph(_ graph: WorkspaceSceneGraph) {
        self.graph = graph
        graphRevision &+= 1
    }
}
