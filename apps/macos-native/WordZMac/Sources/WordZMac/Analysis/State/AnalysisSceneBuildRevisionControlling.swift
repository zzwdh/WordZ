import Foundation

@MainActor
protocol AnalysisSceneBuildRevisionControlling: AnyObject {
    var sceneBuildRevision: Int { get set }
}

@MainActor
extension AnalysisSceneBuildRevisionControlling {
    @discardableResult
    func beginSceneBuildPass() -> Int {
        sceneBuildRevision += 1
        return sceneBuildRevision
    }

    func invalidatePendingSceneBuilds() {
        sceneBuildRevision += 1
    }

    func isCurrentSceneBuild(_ revision: Int) -> Bool {
        revision == sceneBuildRevision
    }
}
