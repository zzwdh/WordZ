import SwiftUI

struct TaskCenterWindowView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var workspace: MainWorkspaceViewModel
    @SceneStorage("wordz.taskCenter.searchQuery") private var searchQuery = ""
    @State private var toolbarProgressCoordinator = NativeTaskCenterToolbarProgressCoordinator()

    var body: some View {
        taskCenterWindowContent(scene: sceneModel)
            .searchable(
                text: $searchQuery,
                placement: .toolbar,
                prompt: t("搜索任务标题、状态或操作", "Search task titles, states, or actions")
            )
            .nativeTaskCenterSearchPresentation()
            .adaptiveWindowScaffold(for: .taskCenter)
            .bindWindowRoute(.taskCenter, titleProvider: { mode in
                NativeWindowRoute.taskCenter.title(in: mode)
            }, onResolve: { window in
                toolbarProgressCoordinator.bind(window: window)
                toolbarProgressCoordinator.update(rootView: toolbarAccessoryView)
            })
            .onAppear {
                toolbarProgressCoordinator.update(rootView: toolbarAccessoryView)
            }
            .onChange(of: sceneModel) { _, _ in
                toolbarProgressCoordinator.update(rootView: toolbarAccessoryView)
            }
            .onDisappear {
                toolbarProgressCoordinator.detach()
            }
            .focusedValue(\.workspaceCommandContext, workspace.commandContext(for: .taskCenter))
            .frame(minWidth: 560, minHeight: 420)
    }

    private var sceneModel: TaskCenterWindowSceneModel {
        TaskCenterWindowSceneModel(
            taskCenterScene: workspace.taskCenter.scene,
            searchQuery: searchQuery,
            languageMode: languageMode
        )
    }

    private var toolbarAccessoryView: AnyView? {
        guard sceneModel.showsAggregateProgress, let aggregateProgress = sceneModel.aggregateProgress else {
            return nil
        }
        return AnyView(
            TaskCenterAggregateProgressView(
                progress: aggregateProgress,
                summary: sceneModel.aggregateProgressSummary,
                style: .titlebarAccessory
            )
        )
    }

    func taskStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func t(_ zh: String, _ en: String) -> String {
        wordZText(zh, en, mode: languageMode)
    }
}
