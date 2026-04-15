import AppKit
import Foundation

@MainActor
package final class NativeApplicationActivityInspector: ApplicationActivityInspecting {
    package init() {}

    package var isApplicationActive: Bool {
        NSApplication.shared.isActive
    }

    package var shouldDeliverBackgroundNotifications: Bool {
        NativeNotificationEnvironment.isRunningTests || !isApplicationActive
    }
}
