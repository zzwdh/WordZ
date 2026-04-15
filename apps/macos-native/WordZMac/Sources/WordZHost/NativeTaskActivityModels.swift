import Foundation

package enum NativeBackgroundTaskState: String, Codable, Equatable {
    case running
    case completed
    case failed
}

package enum NativeBackgroundTaskAction: Equatable {
    case cancelTask(id: UUID)
    case openFile(path: String)
    case openURL(String)
    case installDownloadedUpdate(path: String)
}

package struct NativeBackgroundTaskItem: Identifiable, Equatable {
    package let id: UUID
    package let title: String
    package let detail: String
    package let state: NativeBackgroundTaskState
    package let progress: Double?
    package let startedAt: Date
    package let updatedAt: Date
    package let primaryAction: NativeBackgroundTaskAction?

    package init(
        id: UUID,
        title: String,
        detail: String,
        state: NativeBackgroundTaskState,
        progress: Double?,
        startedAt: Date,
        updatedAt: Date,
        primaryAction: NativeBackgroundTaskAction?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.progress = progress
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.primaryAction = primaryAction
    }

    package var normalizedProgress: Double? {
        guard let progress else { return nil }
        return min(max(progress, 0), 1)
    }
}

package struct PersistedNativeBackgroundTaskAction: Codable, Equatable {
    package let kind: String
    package let value: String

    package init(kind: String, value: String) {
        self.kind = kind
        self.value = value
    }

    package init?(action: NativeBackgroundTaskAction?) {
        guard let action else { return nil }
        switch action {
        case .cancelTask:
            return nil
        case .openFile(let path):
            self.kind = "openFile"
            self.value = path
        case .openURL(let url):
            self.kind = "openURL"
            self.value = url
        case .installDownloadedUpdate(let path):
            self.kind = "installDownloadedUpdate"
            self.value = path
        }
    }

    package var action: NativeBackgroundTaskAction? {
        switch kind {
        case "openFile":
            return .openFile(path: value)
        case "openURL":
            return .openURL(value)
        case "installDownloadedUpdate":
            return .installDownloadedUpdate(path: value)
        default:
            return nil
        }
    }
}

package struct PersistedNativeBackgroundTaskItem: Codable, Equatable {
    package let id: UUID
    package let title: String
    package let detail: String
    package let state: NativeBackgroundTaskState
    package let progress: Double?
    package let startedAt: Date
    package let updatedAt: Date
    package let primaryAction: PersistedNativeBackgroundTaskAction?

    package init(
        id: UUID,
        title: String,
        detail: String,
        state: NativeBackgroundTaskState,
        progress: Double?,
        startedAt: Date,
        updatedAt: Date,
        primaryAction: PersistedNativeBackgroundTaskAction?
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
        self.progress = progress
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.primaryAction = primaryAction
    }

    package init(item: NativeBackgroundTaskItem) {
        self.id = item.id
        self.title = item.title
        self.detail = item.detail
        self.state = item.state
        self.progress = item.progress
        self.startedAt = item.startedAt
        self.updatedAt = item.updatedAt
        self.primaryAction = PersistedNativeBackgroundTaskAction(action: item.primaryAction)
    }

    package func restoredItem(interruptedDetail: String) -> NativeBackgroundTaskItem {
        let restoredState: NativeBackgroundTaskState = state == .running ? .failed : state
        let restoredDetail: String
        if state == .running {
            restoredDetail = detail.isEmpty ? interruptedDetail : "\(detail) \(interruptedDetail)"
        } else {
            restoredDetail = detail
        }
        return NativeBackgroundTaskItem(
            id: id,
            title: title,
            detail: restoredDetail,
            state: restoredState,
            progress: restoredState == .completed ? 1 : (restoredState == .running ? progress : nil),
            startedAt: startedAt,
            updatedAt: updatedAt,
            primaryAction: restoredState == .running ? nil : primaryAction?.action
        )
    }
}
