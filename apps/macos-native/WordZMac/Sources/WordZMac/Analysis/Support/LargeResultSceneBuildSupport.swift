import Foundation

enum LargeResultSceneBuildSupport {
    static let asyncThreshold = ResultPerformanceGuardrails.maximumInteractiveAllRows
    static let queue = DispatchQueue(
        label: "WordZMac.LargeResultSceneBuild",
        qos: .userInitiated,
        attributes: .concurrent
    )
}
