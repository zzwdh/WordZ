import AppKit
import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func attachWindow(_ window: NSWindow?, features: WorkspaceFeatureSet) {
        windowDocumentController.attach(window: window)
        syncWindowDocumentState(features: features)
    }
}
