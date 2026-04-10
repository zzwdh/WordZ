import SwiftUI

extension AboutWindowView {
    var aboutWindowContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            NativeWindowHeader(
                title: workspace.sceneGraph.context.appName,
                subtitle: "\(workspace.sceneGraph.context.versionLabel) · \(workspace.sceneGraph.context.buildSummary)"
            )
            aboutOverviewSection
            aboutQuickActionsSection
            aboutSupportSection
        }
        .padding(20)
    }

    var aboutOverviewSection: some View {
        NativeWindowSection(title: t("原生版概览", "Native Overview"), subtitle: t("纯 Swift 宿主与本地引擎", "Pure Swift host with native engine")) {
            Text(t("当前原生版已经支持语料管理、主分析工作流、工作区恢复、导出、更新检查和原生命令体系。", "The native app now supports corpus management, the main analysis workflow, workspace restore, export, update checks, and native commands."))
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                NativeMetricTile(title: t("版本", "Version"), value: workspace.sceneGraph.context.versionLabel)
                NativeMetricTile(title: t("工作区", "Workspace"), value: workspace.sceneGraph.context.workspaceSummary)
                NativeMetricTile(title: t("语言", "Language"), value: workspace.settings.languageMode.pickerLabel)
                NativeMetricTile(
                    title: t("更新状态", "Update Status"),
                    value: workspace.settings.scene.latestVersionLabel,
                    detail: workspace.settings.scene.updateSummary
                )
            }
        }
    }

    var aboutQuickActionsSection: some View {
        NativeWindowSection(title: t("快速操作", "Quick Actions"), subtitle: t("常用宿主入口", "Common host actions")) {
            HStack {
                Button(t("检查更新", "Check for Updates")) {
                    Task { await workspace.checkForUpdatesNow() }
                }
                Button(t("项目主页", "Project Home")) {
                    Task { await workspace.openProjectHome() }
                }
                Button(t("GitHub 反馈", "GitHub Feedback")) {
                    Task { await workspace.openFeedback() }
                }
            }
        }
    }

    var aboutSupportSection: some View {
        NativeWindowSection(title: t("支持状态", "Support Status"), subtitle: workspace.settings.scene.supportStatus) {
            Text(workspace.settings.scene.supportStatus)
                .fixedSize(horizontal: false, vertical: true)
            if !workspace.settings.scene.userDataDirectory.isEmpty {
                Button(t("打开用户数据目录", "Open User Data Directory")) {
                    Task { await workspace.openUserDataDirectory() }
                }
            }
        }
    }
}
