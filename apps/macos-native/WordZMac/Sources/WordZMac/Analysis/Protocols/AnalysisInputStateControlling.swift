import Foundation

@MainActor
protocol AnalysisInputStateControlling: AnyObject {
    var isApplyingInputState: Bool { get }
    var onInputChange: (() -> Void)? { get }
}

@MainActor
extension AnalysisInputStateControlling {
    func propagateInputChange(
        rebuildScene shouldRebuildScene: Bool,
        rebuild: () -> Void
    ) {
        guard !isApplyingInputState else { return }
        onInputChange?()
        if shouldRebuildScene {
            rebuild()
        }
    }
}
