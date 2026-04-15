import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func copyKWICReading(_ format: ReadingExportFormat, currentOnly: Bool, features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyKWICReading(format, currentOnly: currentOnly, features: features)
    }

    func exportKWICReading(
        _ format: ReadingExportFormat,
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportKWICReading(
            format,
            currentOnly: currentOnly,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyLocatorReading(_ format: ReadingExportFormat, currentOnly: Bool, features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyLocatorReading(format, currentOnly: currentOnly, features: features)
    }

    func exportLocatorReading(
        _ format: ReadingExportFormat,
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportLocatorReading(
            format,
            currentOnly: currentOnly,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCompareReading(currentOnly: Bool, features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyCompareReading(currentOnly: currentOnly, features: features)
    }

    func exportCompareReading(
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportCompareReading(
            currentOnly: currentOnly,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCompareMethodSummary(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyCompareMethodSummary(features: features)
    }

    func copyCollocateReading(currentOnly: Bool, features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyCollocateReading(currentOnly: currentOnly, features: features)
    }

    func exportCollocateReading(
        currentOnly: Bool,
        features: WorkspaceFeatureSet,
        preferredRoute: NativeWindowRoute? = nil
    ) async {
        await analysisWorkflow.exportCollocateReading(
            currentOnly: currentOnly,
            features: features,
            preferredRoute: preferredRoute
        )
    }

    func copyCollocateMethodSummary(features: WorkspaceFeatureSet) async {
        await analysisWorkflow.copyCollocateMethodSummary(features: features)
    }
}
