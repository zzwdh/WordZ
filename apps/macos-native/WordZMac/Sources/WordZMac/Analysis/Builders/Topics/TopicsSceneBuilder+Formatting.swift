import Foundation

extension TopicsSceneBuilder {
    func clusterTitle(for cluster: TopicClusterSummary, mode: AppLanguageMode) -> String {
        if cluster.isOutlier {
            return wordZText("离群片段", "Outliers", mode: mode)
        }
        return "\(wordZText("主题", "Topic", mode: mode)) \(cluster.index)"
    }

    func clusterSummaryText(
        cluster: TopicClusterSummary,
        visibleSegments: Int,
        totalSegments: Int,
        mode: AppLanguageMode
    ) -> String {
        let visibleText = "\(wordZText("显示", "Showing", mode: mode)) \(visibleSegments) / \(totalSegments)"
        let sizeText = "\(wordZText("规模", "Size", mode: mode)) \(cluster.size)"
        return "\(sizeText) · \(visibleText)"
    }
}
