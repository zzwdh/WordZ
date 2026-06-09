import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func localizedTopicProgressDetail(_ progress: TopicAnalysisProgress) -> String {
        switch progress.stage {
        case .preparing:
            return wordZText("正在加载 Topics 模型…", "Loading the Topics model…", mode: .system)
        case .segmenting:
            return wordZText("正在切分语料段落…", "Segmenting corpus paragraphs…", mode: .system)
        case .embedding:
            return wordZText("正在生成段落向量…", "Embedding paragraph vectors…", mode: .system)
        case .clustering:
            return wordZText("正在聚类主题…", "Clustering topics…", mode: .system)
        case .summarizing:
            return wordZText("正在生成关键词与代表片段…", "Building keywords and representative segments…", mode: .system)
        }
    }
}
