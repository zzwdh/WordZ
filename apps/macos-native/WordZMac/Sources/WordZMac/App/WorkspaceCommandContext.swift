import Foundation
import SwiftUI

struct WorkspaceCommandContext: Equatable {
    let route: NativeWindowRoute
    let toolbar: WorkspaceToolbarSceneModel?
    let canRefreshWorkspace: Bool
    let canSelectMainRoute: Bool
    let selectedMainRoute: WorkspaceMainRoute?
    let canToggleInspector: Bool
    let isInspectorPresented: Bool
    let canImportCorpora: Bool
    let canOpenSelectedCorpus: Bool
    let canOpenSourceView: Bool
    let canConfigureAnnotation: Bool
    let canQuickLookContent: Bool
    let canShareContent: Bool
    let canExportCurrent: Bool
    let canMoveEvidenceGroupUp: Bool
    let canMoveEvidenceGroupDown: Bool
    let canSplitEvidenceGroup: Bool
    let canRenameEvidenceGroup: Bool
    let canMergeEvidenceGroup: Bool
    let canExportEvidenceDossier: Bool
    let canExportEvidenceJSON: Bool
    let canSaveAnalysisPreset: Bool
    let canManageAnalysisPresets: Bool
    let canExportReportBundle: Bool

    init(
        route: NativeWindowRoute,
        toolbar: WorkspaceToolbarSceneModel? = nil,
        canRefreshWorkspace: Bool = false,
        canSelectMainRoute: Bool = false,
        selectedMainRoute: WorkspaceMainRoute? = nil,
        canToggleInspector: Bool = false,
        isInspectorPresented: Bool = false,
        canImportCorpora: Bool = false,
        canOpenSelectedCorpus: Bool = false,
        canOpenSourceView: Bool = false,
        canConfigureAnnotation: Bool = false,
        canQuickLookContent: Bool = false,
        canShareContent: Bool = false,
        canExportCurrent: Bool = false,
        canMoveEvidenceGroupUp: Bool = false,
        canMoveEvidenceGroupDown: Bool = false,
        canSplitEvidenceGroup: Bool = false,
        canRenameEvidenceGroup: Bool = false,
        canMergeEvidenceGroup: Bool = false,
        canExportEvidenceDossier: Bool = false,
        canExportEvidenceJSON: Bool = false,
        canSaveAnalysisPreset: Bool = false,
        canManageAnalysisPresets: Bool = false,
        canExportReportBundle: Bool = false
    ) {
        self.route = route
        self.toolbar = toolbar
        self.canRefreshWorkspace = canRefreshWorkspace
        self.canSelectMainRoute = canSelectMainRoute
        self.selectedMainRoute = selectedMainRoute
        self.canToggleInspector = canToggleInspector
        self.isInspectorPresented = isInspectorPresented
        self.canImportCorpora = canImportCorpora
        self.canOpenSelectedCorpus = canOpenSelectedCorpus
        self.canOpenSourceView = canOpenSourceView
        self.canConfigureAnnotation = canConfigureAnnotation
        self.canQuickLookContent = canQuickLookContent
        self.canShareContent = canShareContent
        self.canExportCurrent = canExportCurrent
        self.canMoveEvidenceGroupUp = canMoveEvidenceGroupUp
        self.canMoveEvidenceGroupDown = canMoveEvidenceGroupDown
        self.canSplitEvidenceGroup = canSplitEvidenceGroup
        self.canRenameEvidenceGroup = canRenameEvidenceGroup
        self.canMergeEvidenceGroup = canMergeEvidenceGroup
        self.canExportEvidenceDossier = canExportEvidenceDossier
        self.canExportEvidenceJSON = canExportEvidenceJSON
        self.canSaveAnalysisPreset = canSaveAnalysisPreset
        self.canManageAnalysisPresets = canManageAnalysisPresets
        self.canExportReportBundle = canExportReportBundle
    }

    var supportsWorkspaceCommands: Bool {
        toolbar != nil
    }

    static func == (lhs: WorkspaceCommandContext, rhs: WorkspaceCommandContext) -> Bool {
        lhs.route == rhs.route &&
            lhs.toolbar == rhs.toolbar &&
            lhs.canRefreshWorkspace == rhs.canRefreshWorkspace &&
            lhs.canSelectMainRoute == rhs.canSelectMainRoute &&
            lhs.selectedMainRoute == rhs.selectedMainRoute &&
            lhs.canToggleInspector == rhs.canToggleInspector &&
            lhs.isInspectorPresented == rhs.isInspectorPresented &&
            lhs.canImportCorpora == rhs.canImportCorpora &&
            lhs.canOpenSelectedCorpus == rhs.canOpenSelectedCorpus &&
            lhs.canOpenSourceView == rhs.canOpenSourceView &&
            lhs.canConfigureAnnotation == rhs.canConfigureAnnotation &&
            lhs.canQuickLookContent == rhs.canQuickLookContent &&
            lhs.canShareContent == rhs.canShareContent &&
            lhs.canExportCurrent == rhs.canExportCurrent &&
            lhs.canMoveEvidenceGroupUp == rhs.canMoveEvidenceGroupUp &&
            lhs.canMoveEvidenceGroupDown == rhs.canMoveEvidenceGroupDown &&
            lhs.canSplitEvidenceGroup == rhs.canSplitEvidenceGroup &&
            lhs.canRenameEvidenceGroup == rhs.canRenameEvidenceGroup &&
            lhs.canMergeEvidenceGroup == rhs.canMergeEvidenceGroup &&
            lhs.canExportEvidenceDossier == rhs.canExportEvidenceDossier &&
            lhs.canExportEvidenceJSON == rhs.canExportEvidenceJSON &&
            lhs.canSaveAnalysisPreset == rhs.canSaveAnalysisPreset &&
            lhs.canManageAnalysisPresets == rhs.canManageAnalysisPresets &&
            lhs.canExportReportBundle == rhs.canExportReportBundle
    }

    func applyingViewMenuState(
        selectedMainRoute: WorkspaceMainRoute,
        isInspectorPresented: Bool
    ) -> WorkspaceCommandContext {
        WorkspaceCommandContext(
            route: route,
            toolbar: toolbar,
            canRefreshWorkspace: canRefreshWorkspace,
            canSelectMainRoute: true,
            selectedMainRoute: selectedMainRoute,
            canToggleInspector: true,
            isInspectorPresented: isInspectorPresented,
            canImportCorpora: canImportCorpora,
            canOpenSelectedCorpus: canOpenSelectedCorpus,
            canOpenSourceView: canOpenSourceView,
            canConfigureAnnotation: canConfigureAnnotation,
            canQuickLookContent: canQuickLookContent,
            canShareContent: canShareContent,
            canExportCurrent: canExportCurrent,
            canMoveEvidenceGroupUp: canMoveEvidenceGroupUp,
            canMoveEvidenceGroupDown: canMoveEvidenceGroupDown,
            canSplitEvidenceGroup: canSplitEvidenceGroup,
            canRenameEvidenceGroup: canRenameEvidenceGroup,
            canMergeEvidenceGroup: canMergeEvidenceGroup,
            canExportEvidenceDossier: canExportEvidenceDossier,
            canExportEvidenceJSON: canExportEvidenceJSON,
            canSaveAnalysisPreset: canSaveAnalysisPreset,
            canManageAnalysisPresets: canManageAnalysisPresets,
            canExportReportBundle: canExportReportBundle
        )
    }
}

private struct WorkspaceCommandContextKey: FocusedValueKey {
    typealias Value = WorkspaceCommandContext
}

extension FocusedValues {
    var workspaceCommandContext: WorkspaceCommandContext? {
        get { self[WorkspaceCommandContextKey.self] }
        set { self[WorkspaceCommandContextKey.self] = newValue }
    }
}

extension MainWorkspaceViewModel {
    func commandContext(for route: NativeWindowRoute) -> WorkspaceCommandContext {
        switch route {
        case .mainWorkspace:
            return WorkspaceCommandContext(
                route: route,
                toolbar: shell.scene.toolbar,
                canRefreshWorkspace: true,
                selectedMainRoute: selectedRoute,
                canImportCorpora: true,
                canOpenSelectedCorpus: shell.scene.toolbar.item(for: .openSelected)?.isEnabled ?? false,
                canOpenSourceView: shell.scene.toolbar.item(for: .openSourceReader)?.isEnabled ?? false,
                canConfigureAnnotation: shell.scene.toolbar.item(for: .annotationControls)?.isEnabled ?? false,
                canQuickLookContent: canQuickLookCurrentCorpus,
                canShareContent: canShareCurrentContent,
                canExportCurrent: shell.scene.toolbar.item(for: .exportCurrent)?.isEnabled ?? false,
                canSaveAnalysisPreset: canManageAnalysisPresets,
                canManageAnalysisPresets: canManageAnalysisPresets,
                canExportReportBundle: canExportCurrentReportBundle
            )
        case .library:
            return WorkspaceCommandContext(
                route: route,
                canImportCorpora: true,
                canOpenSelectedCorpus: library.selectedCorpusID != nil,
                canOpenSourceView: false,
                canConfigureAnnotation: false,
                canQuickLookContent: selectedCorpusPreviewablePath != nil,
                canShareContent: selectedCorpusPreviewablePath != nil,
                canExportCurrent: false,
                canSaveAnalysisPreset: false,
                canManageAnalysisPresets: false,
                canExportReportBundle: false
            )
        case .evidenceWorkbench:
            let groupingMode = evidenceWorkbench.groupingMode
            let hasSelectedGroup = evidenceWorkbench.selectedGroup(in: .system) != nil
            return WorkspaceCommandContext(
                route: route,
                canImportCorpora: false,
                canOpenSelectedCorpus: false,
                canOpenSourceView: false,
                canConfigureAnnotation: false,
                canQuickLookContent: false,
                canShareContent: false,
                canExportCurrent: false,
                canMoveEvidenceGroupUp: evidenceWorkbench.canMoveSelectedGroupUp,
                canMoveEvidenceGroupDown: evidenceWorkbench.canMoveSelectedGroupDown,
                canSplitEvidenceGroup: evidenceWorkbench.canSplitSelectedGroup,
                canRenameEvidenceGroup: groupingMode.supportsItemAssignment && hasSelectedGroup,
                canMergeEvidenceGroup: groupingMode.supportsItemAssignment && hasSelectedGroup,
                canExportEvidenceDossier: evidenceWorkbench.items.contains(where: { $0.reviewStatus == .keep }),
                canExportEvidenceJSON: !evidenceWorkbench.items.isEmpty,
                canSaveAnalysisPreset: false,
                canManageAnalysisPresets: false,
                canExportReportBundle: false
            )
        case .sourceReader:
            return WorkspaceCommandContext(
                route: route,
                canImportCorpora: false,
                canOpenSelectedCorpus: false,
                canOpenSourceView: false,
                canConfigureAnnotation: true,
                canQuickLookContent: false,
                canShareContent: false,
                canExportCurrent: false,
                canSaveAnalysisPreset: false,
                canManageAnalysisPresets: false,
                canExportReportBundle: false
            )
        case .settings:
            return WorkspaceCommandContext(
                route: route,
                canImportCorpora: true,
                canOpenSelectedCorpus: false,
                canOpenSourceView: false,
                canConfigureAnnotation: false,
                canQuickLookContent: false,
                canShareContent: false,
                canExportCurrent: false,
                canSaveAnalysisPreset: false,
                canManageAnalysisPresets: false,
                canExportReportBundle: false
            )
        case .taskCenter, .updatePrompt, .about, .help, .releaseNotes:
            return WorkspaceCommandContext(
                route: route,
                canImportCorpora: false,
                canOpenSelectedCorpus: false,
                canOpenSourceView: false,
                canConfigureAnnotation: false,
                canQuickLookContent: false,
                canShareContent: false,
                canExportCurrent: false,
                canSaveAnalysisPreset: false,
                canManageAnalysisPresets: false,
                canExportReportBundle: false
            )
        }
    }
}
