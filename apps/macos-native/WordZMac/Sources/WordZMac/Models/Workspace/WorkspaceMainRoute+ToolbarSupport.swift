import Foundation

extension WorkspaceMainRoute {
    var toolbarRunAction: WorkspaceToolbarAction? {
        WorkspaceFeatureRegistry.descriptor(for: self).commandAction
    }
}
