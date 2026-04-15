import Foundation

@MainActor
protocol WorkspaceResultSceneNodeBuilding {
    func makeWordNode(from scene: WordSceneModel?) -> WorkspaceResultSceneNode
    func makeTokenizeNode(from scene: TokenizeSceneModel?) -> WorkspaceResultSceneNode
    func makeStatsNode(from scene: StatsSceneModel?) -> WorkspaceResultSceneNode
    func makeTopicsNode(from scene: TopicsSceneModel?) -> WorkspaceResultSceneNode
    func makeCompareNode(from scene: CompareSceneModel?) -> WorkspaceResultSceneNode
    func makeSentimentNode(from scene: SentimentSceneModel?) -> WorkspaceResultSceneNode
    func makeKeywordNode(from scene: KeywordSceneModel?) -> WorkspaceResultSceneNode
    func makeChiSquareNode(from scene: ChiSquareSceneModel?) -> WorkspaceResultSceneNode
    func makePlotNode(from scene: PlotSceneModel?) -> WorkspaceResultSceneNode
    func makeNgramNode(from scene: NgramSceneModel?) -> WorkspaceResultSceneNode
    func makeClusterNode(from scene: ClusterSceneModel?) -> WorkspaceResultSceneNode
    func makeKWICNode(from scene: KWICSceneModel?) -> WorkspaceResultSceneNode
    func makeCollocateNode(from scene: CollocateSceneModel?) -> WorkspaceResultSceneNode
    func makeLocatorNode(from scene: LocatorSceneModel?) -> WorkspaceResultSceneNode
}

@MainActor
protocol WorkspaceResultSceneNodeBuildingFactory {
    func make(languageMode: AppLanguageMode) -> any WorkspaceResultSceneNodeBuilding
}

struct DefaultWorkspaceResultSceneNodeBuilderFactory: WorkspaceResultSceneNodeBuildingFactory {
    func make(languageMode: AppLanguageMode) -> any WorkspaceResultSceneNodeBuilding {
        WorkspaceResultSceneNodeBuilder(languageMode: languageMode)
    }
}
