import Foundation

enum SceneSyncSource {
    case full
    case navigation
    case librarySelection
    case resultContent
    case settings
}

struct SceneGraphMutationSet: OptionSet, Equatable {
    let rawValue: Int

    static let full = SceneGraphMutationSet(rawValue: 1 << 0)
    static let navigation = SceneGraphMutationSet(rawValue: 1 << 1)
    static let librarySelection = SceneGraphMutationSet(rawValue: 1 << 2)
    static let resultContent = SceneGraphMutationSet(rawValue: 1 << 3)
    static let settings = SceneGraphMutationSet(rawValue: 1 << 4)

    var normalized: SceneGraphMutationSet {
        if contains(.full) {
            return [.full]
        }
        var value = self
        if value.contains(.librarySelection) {
            value.remove(.navigation)
        }
        return value
    }
}

struct SceneSyncPlan: Equatable {
    let mutations: SceneGraphMutationSet
    let syncWorkflowLibraryState: Bool
    let refreshChromeState: Bool
    let rebuildRootScene: Bool
    let rebuildWelcomeScene: Bool

    func merged(with other: SceneSyncPlan) -> SceneSyncPlan {
        SceneSyncPlan(
            mutations: mutations.union(other.mutations).normalized,
            syncWorkflowLibraryState: syncWorkflowLibraryState || other.syncWorkflowLibraryState,
            refreshChromeState: refreshChromeState || other.refreshChromeState,
            rebuildRootScene: rebuildRootScene || other.rebuildRootScene,
            rebuildWelcomeScene: rebuildWelcomeScene || other.rebuildWelcomeScene
        )
    }
}

extension SceneSyncSource {
    var plan: SceneSyncPlan {
        switch self {
        case .full:
            return SceneSyncPlan(
                mutations: [.full],
                syncWorkflowLibraryState: true,
                refreshChromeState: true,
                rebuildRootScene: true,
                rebuildWelcomeScene: true
            )
        case .navigation:
            return SceneSyncPlan(
                mutations: [.navigation],
                syncWorkflowLibraryState: false,
                refreshChromeState: true,
                rebuildRootScene: true,
                rebuildWelcomeScene: false
            )
        case .librarySelection:
            return SceneSyncPlan(
                mutations: [.librarySelection],
                syncWorkflowLibraryState: true,
                refreshChromeState: true,
                rebuildRootScene: false,
                rebuildWelcomeScene: false
            )
        case .resultContent:
            return SceneSyncPlan(
                mutations: [.resultContent],
                syncWorkflowLibraryState: false,
                refreshChromeState: true,
                rebuildRootScene: false,
                rebuildWelcomeScene: false
            )
        case .settings:
            return SceneSyncPlan(
                mutations: [.settings],
                syncWorkflowLibraryState: false,
                refreshChromeState: false,
                rebuildRootScene: true,
                rebuildWelcomeScene: true
            )
        }
    }
}
