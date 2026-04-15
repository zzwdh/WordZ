import SwiftUI

extension TaskCenterWindowView {
    func taskCenterWindowContent(scene: TaskCenterWindowSceneModel) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("任务中心", "Task Center"),
                subtitle: scene.subtitle
            ) {
                Button(t("清理已结束", "Clear Finished")) {
                    workspace.clearFinishedTasks()
                }
                .disabled(!scene.hasFinishedItems)
            }
            if !NativePlatformCapabilities.current.supportsToolbarSearchEnhancements,
               scene.showsAggregateProgress,
               let aggregateProgress = scene.aggregateProgress {
                TaskCenterAggregateProgressView(
                    progress: aggregateProgress,
                    summary: scene.aggregateProgressSummary,
                    style: .content
                )
            }
            metricsRow(scene: scene)
            taskCenterListSection(scene: scene)
        }
        .padding(20)
    }

    func metricsRow(scene: TaskCenterWindowSceneModel) -> some View {
        HStack(spacing: 12) {
            NativeMetricTile(title: t("进行中", "Running"), value: "\(scene.runningCount)")
            NativeMetricTile(title: t("已完成", "Completed"), value: "\(scene.completedCount)")
            NativeMetricTile(title: t("失败", "Failed"), value: "\(scene.failedCount)")
        }
    }

    @ViewBuilder
    func taskCenterListSection(scene: TaskCenterWindowSceneModel) -> some View {
        if scene.isEmpty {
            ContentUnavailableView(
                t("当前没有后台任务", "No background tasks"),
                systemImage: "checklist",
                description: Text(t("更新检查、更新下载和诊断包导出会在这里显示进度与结果。", "Update checks, downloads, and diagnostics bundle exports will appear here."))
            )
        } else if scene.showsSearchEmptyState {
            ContentUnavailableView(
                t("没有匹配的任务", "No matching tasks"),
                systemImage: "magnifyingglass",
                description: Text(t("试试搜索任务标题、状态文案或操作名称。", "Try searching by task title, state label, or action name."))
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(scene.sections) { section in
                        taskCenterSection(section)
                    }
                }
                .padding(.bottom, 12)
            }
        }
    }

    func taskCenterSection(_ section: TaskCenterWindowSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.title)
                    .font(.headline)

                Text(section.itemCountSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()

                Spacer(minLength: 0)
            }

            ForEach(section.items) { item in
                taskCenterItemCard(item)
            }
        }
    }

    func taskCenterItemCard(_ item: NativeBackgroundTaskItem) -> some View {
        NativeWindowSection(title: item.title, subtitle: item.detail) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Label(item.state.displayLabel(in: languageMode), systemImage: item.state.symbolName)
                        .symbolRenderingMode(.multicolor)

                    Spacer()

                    if item.state == .running {
                        Text(item.progressLabel(in: languageMode))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text(WordZLocalization.localizedDateTimeString(from: item.updatedAt, mode: languageMode))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if item.state == .running {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: item.normalizedProgress)
                            .frame(maxWidth: .infinity)
                            .tint(.accentColor)
                        Text(item.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let action = item.primaryAction {
                    HStack {
                        Spacer()
                        Button(action.title(in: languageMode)) {
                            Task {
                                await workspace.performTaskAction(action)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
}
