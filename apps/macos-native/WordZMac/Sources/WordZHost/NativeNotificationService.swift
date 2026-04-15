import Foundation
import UserNotifications

package enum NativeNotificationEnvironment {
    package static var isRunningTests: Bool {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || NSClassFromString("XCTestCase") != nil
            || Bundle.allBundles.contains(where: { $0.bundleURL.pathExtension == "xctest" })
    }

    package static var supportsUserNotifications: Bool {
        guard !isRunningTests else { return false }
        let bundleURL = Bundle.main.bundleURL
        return bundleURL.pathExtension == "app"
    }
}

@MainActor
package protocol NativeNotificationServicing: AnyObject {
    func notify(title: String, subtitle: String, body: String) async
}

@MainActor
package final class NoOpNotificationService: NativeNotificationServicing {
    package init() {}

    package func notify(title: String, subtitle: String, body: String) async {}
}

@MainActor
package final class NativeNotificationService: NativeNotificationServicing {
    private lazy var center = UNUserNotificationCenter.current()
    private var authorizationAttempted = false

    package init() {}

    package func notify(title: String, subtitle: String, body: String) async {
        guard NativeNotificationEnvironment.supportsUserNotifications else {
            return
        }
        do {
            try await ensureAuthorizationIfNeeded()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.subtitle = subtitle
            content.body = body
            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
            try await center.add(request)
        } catch {
            // Notifications are non-critical; ignore delivery failures.
        }
    }

    private func ensureAuthorizationIfNeeded() async throws {
        guard NativeNotificationEnvironment.supportsUserNotifications else { return }
        guard !authorizationAttempted else { return }
        authorizationAttempted = true
        _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
