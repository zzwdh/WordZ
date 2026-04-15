import Foundation

enum HostNotificationEvent: Equatable {
    case taskCompleted(title: String, detail: String)
    case taskFailed(title: String, detail: String)

    func localizedContent(mode: AppLanguageMode) -> (title: String, subtitle: String, body: String) {
        switch self {
        case .taskCompleted(let title, let detail):
            return (
                title,
                wordZText("已完成", "Completed", mode: mode),
                detail
            )
        case .taskFailed(let title, let detail):
            return (
                title,
                wordZText("失败", "Failed", mode: mode),
                detail
            )
        }
    }
}
