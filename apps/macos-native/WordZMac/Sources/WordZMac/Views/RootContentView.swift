import SwiftUI

struct RootContentView: View {
    @StateObject private var viewModel = MainWorkspaceViewModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(
                viewModel: viewModel,
                onRefresh: { Task { await viewModel.refreshAll() } },
                onOpenSelected: { Task { await viewModel.openSelectedCorpus() } }
            )
        } detail: {
            TabView(selection: $viewModel.selectedTab) {
                StatsView(
                    result: viewModel.statsResult,
                    onRun: { Task { await viewModel.runStats() } }
                )
                .tabItem { Text("Stats") }
                .tag(MainWorkspaceViewModel.DetailTab.stats)

                KWICView(
                    viewModel: viewModel,
                    onRun: { Task { await viewModel.runKWIC() } }
                )
                .tabItem { Text("KWIC") }
                .tag(MainWorkspaceViewModel.DetailTab.kwic)

                settingsView
                    .tabItem { Text("Settings") }
                    .tag(MainWorkspaceViewModel.DetailTab.settings)
            }
            .toolbar {
                ToolbarItemGroup {
                    Button("刷新") {
                        Task { await viewModel.refreshAll() }
                    }
                    Button("打开选中") {
                        Task { await viewModel.openSelectedCorpus() }
                    }
                    .disabled(viewModel.selectedCorpusID == nil)
                    Divider()
                    Button("统计") {
                        Task { await viewModel.runStats() }
                    }
                    Button("KWIC") {
                        Task { await viewModel.runKWIC() }
                    }
                }
            }
        }
        .navigationTitle(viewModel.appInfo?.name ?? "WordZ Native Preview")
        .task {
            await viewModel.initializeIfNeeded()
        }
    }

    private var settingsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.weight(.semibold))
                Text("这一页先承载原生版第一阶段的状态展示。后续会接入工作区恢复、UI 偏好和文档窗口语义。")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Build")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.buildSummary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Workspace")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(viewModel.workspaceSummary)
                }
                .padding(12)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if let help = viewModel.appInfo?.help, !help.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Help")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(help, id: \.self) { line in
                            Text("• \(line)")
                        }
                    }
                    .padding(12)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(20)
        }
    }
}
