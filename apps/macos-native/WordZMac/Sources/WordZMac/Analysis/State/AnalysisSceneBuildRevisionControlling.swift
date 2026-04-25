import Foundation

@MainActor
protocol AnalysisSceneBuildRevisionControlling: AnyObject {
    var sceneBuildRevision: Int { get set }
}

@MainActor
extension AnalysisSceneBuildRevisionControlling {
    @discardableResult
    func beginSceneBuildPass() -> Int {
        AnalysisSceneBuildScheduling.cancel(owner: self)
        sceneBuildRevision += 1
        return sceneBuildRevision
    }

    func invalidatePendingSceneBuilds() {
        AnalysisSceneBuildScheduling.cancel(owner: self)
        sceneBuildRevision += 1
    }

    func isCurrentSceneBuild(_ revision: Int) -> Bool {
        revision == sceneBuildRevision
    }
}
