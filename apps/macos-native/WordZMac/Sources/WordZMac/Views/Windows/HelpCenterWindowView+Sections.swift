import SwiftUI

extension HelpCenterWindowView {
    var helpCenterWindowContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            NativeWindowHeader(
                title: t("使用说明", "Usage Guide"),
                subtitle: workspace.sceneGraph.context.versionLabel
            ) {
                Button(t("打开项目主页", "Open Project Home")) {
                    Task { await workspace.openProjectHome() }
                }
            }
            quickStartSection
            searchSyntaxSection
            commonWorkflowsSection
            troubleshootingSection
            supportFeedbackSection
        }
        .padding(20)
    }

    var quickStartSection: some View {
        NativeWindowSection(title: t("快速开始", "Quick Start")) {
            helpRow(t("导入语料", "Import Corpus"), shortcut: "⌘O")
            helpRow(t("打开设置", "Open Settings"), shortcut: "⌘,")
            helpRow(t("刷新工作区", "Refresh Workspace"), shortcut: "⌘R")
            helpRow(t("运行当前页面", "Run Current Page"), shortcut: "主按钮 / Main button")
        }
    }

    var searchSyntaxSection: some View {
        NativeWindowSection(title: t("搜索语法", "Search Syntax")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("• \(t("普通词：hacker 只匹配 hacker", "Literal term: hacker only matches hacker"))")
                Text("• \(t("通配：hacker* 可匹配 hacker / hackers", "Wildcard: hacker* can match hacker / hackers"))")
                Text("• \(t("单字符：hack?r 可匹配 hacker / hackor", "Single character: hack?r can match hacker / hackor"))")
                Text("• \(t("开启正则后，* 和 ? 将按正则语义处理", "When regex is enabled, * and ? follow regex rules"))")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    var commonWorkflowsSection: some View {
        NativeWindowSection(title: t("常用流程", "Common Workflows")) {
            VStack(alignment: .leading, spacing: 8) {
                Text("1. \(t("在语料库里导入并打开语料", "Import and open a corpus from Library"))")
                Text("2. \(t("在下拉页面菜单里切到统计、词表、KWIC 或 Topics", "Use the page dropdown to switch to Stats, Word, KWIC, or Topics"))")
                Text("3. \(t("设置检索词或筛选条件后运行当前页面", "Set a query or filters, then run the current page"))")
                Text("4. \(t("需要表格时用列菜单、排序和导出", "Use columns, sorting, and export when you need a table"))")
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
    }

    var troubleshootingSection: some View {
        NativeWindowSection(title: t("排查问题", "Troubleshooting"), subtitle: workspace.settings.scene.supportStatus) {
            if let issue = workspace.issueBanner {
                WorkbenchIssueBanner(tone: issue.tone, title: issue.title, message: issue.message)
            }
            HStack {
                Button(t("刷新工作区", "Refresh Workspace")) {
                    Task { await workspace.refreshAll() }
                }
                Button(t("导出诊断包", "Export Diagnostics Bundle")) {
                    Task { await workspace.exportDiagnostics(preferredWindowRoute: .help) }
                }
                if !workspace.settings.scene.userDataDirectory.isEmpty {
                    Button(t("打开数据目录", "Open Data Directory")) {
                        Task { await workspace.openUserDataDirectory() }
                    }
                }
            }
        }
    }

    var supportFeedbackSection: some View {
        NativeWindowSection(title: t("支持与反馈", "Support & Feedback"), subtitle: workspace.settings.scene.supportStatus) {
            HStack {
                Button(t("导出诊断包", "Export Diagnostics Bundle")) {
                    Task { await workspace.exportDiagnostics(preferredWindowRoute: .help) }
                }
                Button(t("GitHub 反馈", "GitHub Feedback")) { Task { await workspace.openFeedback() } }
                Button(t("版本说明", "Release Notes")) { Task { await workspace.openReleaseNotes() } }
            }
        }
    }
}
