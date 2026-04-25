import Foundation

@MainActor
struct WorkspaceSentimentWorkflowContext {
    private let baseFeatureSet: WorkspaceFeatureSet

    init(featureSet: WorkspaceFeatureSet) {
        self.baseFeatureSet = featureSet
    }

    var sidebar: LibrarySidebarViewModel { baseFeatureSet.sidebar }
    var shell: WorkspaceShellViewModel { baseFeatureSet.shell }
    var library: LibraryManagementViewModel { baseFeatureSet.library }
    var topics: any WorkspaceTopicsPageState { baseFeatureSet.topics }
    var compare: ComparePageViewModel { baseFeatureSet.compare }
    var sentiment: any WorkspaceSentimentPageState { baseFeatureSet.sentiment }
    var kwic: KWICPageViewModel { baseFeatureSet.kwic }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) throws -> T) rethrows -> T {
        try operation(baseFeatureSet)
    }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) async throws -> T) async rethrows -> T {
        try await operation(baseFeatureSet)
    }
}

@MainActor
struct WorkspaceTopicsWorkflowContext {
    private let baseFeatureSet: WorkspaceFeatureSet

    init(featureSet: WorkspaceFeatureSet) {
        self.baseFeatureSet = featureSet
    }

    var sidebar: LibrarySidebarViewModel { baseFeatureSet.sidebar }
    var shell: WorkspaceShellViewModel { baseFeatureSet.shell }
    var topics: any WorkspaceTopicsPageState { baseFeatureSet.topics }
    var compare: ComparePageViewModel { baseFeatureSet.compare }
    var sentiment: any WorkspaceSentimentPageState { baseFeatureSet.sentiment }
    var kwic: KWICPageViewModel { baseFeatureSet.kwic }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) throws -> T) rethrows -> T {
        try operation(baseFeatureSet)
    }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) async throws -> T) async rethrows -> T {
        try await operation(baseFeatureSet)
    }
}

@MainActor
struct WorkspaceEvidenceWorkflowContext {
    private let baseFeatureSet: WorkspaceFeatureSet

    init(featureSet: WorkspaceFeatureSet) {
        self.baseFeatureSet = featureSet
    }

    var sidebar: LibrarySidebarViewModel { baseFeatureSet.sidebar }
    var library: LibraryManagementViewModel { baseFeatureSet.library }
    var sentiment: any WorkspaceSentimentPageState { baseFeatureSet.sentiment }
    var kwic: KWICPageViewModel { baseFeatureSet.kwic }
    var locator: LocatorPageViewModel { baseFeatureSet.locator }
    var evidenceWorkbench: any WorkspaceEvidenceWorkbenchState { baseFeatureSet.evidenceWorkbench }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) throws -> T) rethrows -> T {
        try operation(baseFeatureSet)
    }

    func withFeatureSet<T>(_ operation: @MainActor (WorkspaceFeatureSet) async throws -> T) async rethrows -> T {
        try await operation(baseFeatureSet)
    }
}

@MainActor
extension WorkspaceFeatureSet {
    var sentimentWorkflowContext: WorkspaceSentimentWorkflowContext {
        WorkspaceSentimentWorkflowContext(featureSet: self)
    }

    var topicsWorkflowContext: WorkspaceTopicsWorkflowContext {
        WorkspaceTopicsWorkflowContext(featureSet: self)
    }

    var evidenceWorkflowContext: WorkspaceEvidenceWorkflowContext {
        WorkspaceEvidenceWorkflowContext(featureSet: self)
    }
}
