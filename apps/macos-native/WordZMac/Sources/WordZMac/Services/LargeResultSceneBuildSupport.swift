import Foundation

enum LargeResultSceneBuildSupport {
    static let asyncThreshold = 1_500
    static let queue = DispatchQueue(
        label: "WordZMac.LargeResultSceneBuild",
        qos: .userInitiated,
        attributes: .concurrent
    )
}
