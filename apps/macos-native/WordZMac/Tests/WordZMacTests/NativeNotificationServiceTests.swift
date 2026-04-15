import XCTest
@testable import WordZWorkspaceCore

final class NativeNotificationServiceTests: XCTestCase {
    func testSupportsUserNotificationsIsDisabledDuringTests() {
        XCTAssertTrue(NativeNotificationEnvironment.isRunningTests)
        XCTAssertFalse(NativeNotificationEnvironment.supportsUserNotifications)
    }
}
