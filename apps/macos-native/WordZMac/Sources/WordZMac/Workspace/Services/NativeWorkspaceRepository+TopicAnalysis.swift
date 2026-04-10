import Foundation

extension NativeWorkspaceRepositoryCore {
    func runTopics(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult {
        try await topicEngine.analyze(text: text, options: options, progress: progress)
    }
}
