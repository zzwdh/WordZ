import XCTest
@testable import WordZWorkspaceCore

import WordZHost
final class NativeNotificationServiceTests: XCTestCase {
    func testSupportsUserNotificationsIsDisabledDuringTests() {
        XCTAssertTrue(NativeNotificationEnvironment.isRunningTests)
        XCTAssertFalse(NativeNotificationEnvironment.supportsUserNotifications)
    }
}
