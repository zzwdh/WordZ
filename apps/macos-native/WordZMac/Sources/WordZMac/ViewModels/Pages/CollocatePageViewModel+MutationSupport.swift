import Foundation

extension CollocatePageViewModel {
    func performConfigurationMutation(
        rebuildScene shouldRebuildScene: Bool,
        mutation: () -> Void
    ) {
        applyStateChange {
            mutation()
        }

        onInputChange?()
        if shouldRebuildScene {
            rebuildScene()
        }
    }

    func performPresentationMutation(_ mutation: () -> Void) {
        applyStateChange(rebuildScene: rebuildScene) {
            mutation()
            currentPage = 1
        }
    }

    func applyMetricPresentation(_ metric: CollocateAssociationMetric) {
        switch metric {
        case .logDice:
            sortMode = .logDiceDescending
            visibleColumns.insert(.logDice)
        case .mutualInformation:
            sortMode = .mutualInformationDescending
            visibleColumns.insert(.mutualInformation)
        case .tScore:
            sortMode = .tScoreDescending
            visibleColumns.insert(.tScore)
        case .rate:
            sortMode = .rateDescending
            visibleColumns.insert(.rate)
        case .frequency:
            sortMode = .frequencyDescending
            visibleColumns.insert(.total)
        }
    }
}
