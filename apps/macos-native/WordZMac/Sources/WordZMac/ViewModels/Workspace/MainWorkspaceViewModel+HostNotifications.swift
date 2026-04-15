import Foundation

@MainActor
extension MainWorkspaceViewModel {
    func emitHostNotification(_ event: HostNotificationEvent) async {
        if !applicationActivityInspector.shouldDeliverBackgroundNotifications {
            return
        }

        let content = event.localizedContent(mode: languageMode)
        await notificationService.notify(
            title: content.title,
            subtitle: content.subtitle,
            body: content.body
        )
    }

    func emitHostNotificationForTask(_ item: NativeBackgroundTaskItem) async {
        switch item.state {
        case .running:
            return
        case .completed:
            await emitHostNotification(.taskCompleted(title: item.title, detail: item.detail))
        case .failed:
            let lowercasedDetail = item.detail.lowercased()
            guard !lowercasedDetail.contains("cancelled"), !lowercasedDetail.contains("已取消") else {
                return
            }
            await emitHostNotification(.taskFailed(title: item.title, detail: item.detail))
        }
    }
}
