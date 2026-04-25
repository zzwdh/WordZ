import SwiftUI

extension WorkspaceFeatureRegistry {
    static func topicsDescriptor() -> WorkspaceFeatureDescriptor {
        .init(
            key: .topics,
            route: .topics,
            tab: .topics,
            titleZh: "主题",
            titleEn: "Topics",
            sidebarSubtitleZh: "查看主题簇、代表词与片段分布",
            sidebarSubtitleEn: "Inspect topic clusters, keywords, and segment spread",
            symbolName: "square.grid.3x3.topleft.filled",
            commandAction: .runTopics,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    TopicsView(
                        viewModel: workspace.topics,
                        isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.topics),
                        onAction: dispatcher.handleTopicsAction
                    )
                )
            }
        )
    }

    static func sentimentDescriptor() -> WorkspaceFeatureDescriptor {
        .init(
            key: .sentiment,
            route: .sentiment,
            tab: .sentiment,
            titleZh: "情感",
            titleEn: "Sentiment",
            sidebarSubtitleZh: "查看 neutrality / positivity / negativity 的启发式分布",
            sidebarSubtitleEn: "Inspect heuristic neutrality / positivity / negativity distributions",
            symbolName: "waveform.path.ecg.text",
            commandAction: .runSentiment,
            showsInSidebar: true,
            showsInPagePicker: true,
            showsInCommands: true,
            detailViewBuilder: { workspace, dispatcher in
                AnyView(
                    SentimentView(
                        viewModel: workspace.sentiment,
                        isBusy: workspace.isFeatureBusy(WorkspaceFeatureKey.sentiment),
                        onAction: dispatcher.handleSentimentAction
                    )
                )
            }
        )
    }
}
