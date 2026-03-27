import XCTest
@testable import WordZMac

final class NativeNotificationServiceTests: XCTestCase {
    func testSupportsUserNotificationsIsDisabledDuringTests() {
        XCTAssertTrue(NativeNotificationEnvironment.isRunningTests)
        XCTAssertFalse(NativeNotificationEnvironment.supportsUserNotifications)
    }
}
