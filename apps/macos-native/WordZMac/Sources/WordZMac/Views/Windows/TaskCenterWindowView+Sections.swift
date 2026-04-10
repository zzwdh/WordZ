import SwiftUI

extension TaskCenterWindowView {
    var taskCenterWindowContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("任务中心", "Task Center"),
                subtitle: workspace.taskCenter.scene.summary
            ) {
                Button(t("清理已完成", "Clear Completed")) {
                    workspace.clearFinishedTasks()
                }
                .disabled(workspace.taskCenter.scene.items.allSatisfy { $0.state == .running })
            }
            metricsRow
            taskCenterListSection
        }
        .padding(20)
    }

    var metricsRow: some View {
        HStack(spacing: 12) {
            NativeMetricTile(title: t("进行中", "Running"), value: "\(workspace.taskCenter.scene.runningCount)")
            NativeMetricTile(title: t("已完成", "Completed"), value: "\(workspace.taskCenter.scene.completedCount)")
            NativeMetricTile(title: t("失败", "Failed"), value: "\(workspace.taskCenter.scene.failedCount)")
            NativeMetricTile(
                title: t("整体进度", "Overall Progress"),
                value: workspace.taskCenter.scene.aggregateProgress.map { "\(Int(($0 * 100).rounded()))%" } ?? "—",
                detail: workspace.taskCenter.scene.runningCount > 0
                    ? t("按当前运行任务计算", "Based on currently running tasks")
                    : t("当前没有运行中的任务", "No tasks are currently running")
            )
        }
    }

    @ViewBuilder
    var taskCenterListSection: some View {
        if workspace.taskCenter.scene.items.isEmpty {
            ContentUnavailableView(
                t("当前没有后台任务", "No background tasks"),
                systemImage: "checklist",
                description: Text(t("更新检查、更新下载和诊断包导出会在这里显示进度与结果。", "Update checks, downloads, and diagnostics bundle exports will appear here."))
            )
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(workspace.taskCenter.scene.items) { item in
                        taskCenterItemCard(item)
                    }
                }
                .padding(.bottom, 12)
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
                        Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
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
