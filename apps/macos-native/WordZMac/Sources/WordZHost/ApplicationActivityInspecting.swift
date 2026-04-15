import Foundation

@MainActor
package protocol ApplicationActivityInspecting: AnyObject {
    var isApplicationActive: Bool { get }
    var shouldDeliverBackgroundNotifications: Bool { get }
}
