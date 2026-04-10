import Foundation

@MainActor
protocol AnalysisStateApplying: AnyObject {
    var isApplyingStateFlag: Bool { get set }
}

@MainActor
extension AnalysisStateApplying {
    func applyStateChange(
        rebuildScene: (() -> Void)? = nil,
        mutation: () -> Void
    ) {
        isApplyingStateFlag = true
        defer {
            isApplyingStateFlag = false
            rebuildScene?()
        }
        mutation()
    }

    func resetState(
        cancelPendingSceneBuilds: (() -> Void)? = nil,
        mutation: () -> Void
    ) {
        cancelPendingSceneBuilds?()
        isApplyingStateFlag = true
        defer { isApplyingStateFlag = false }
        mutation()
    }
}
