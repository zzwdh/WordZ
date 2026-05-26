import CoreGraphics
import Foundation
import SwiftUI

package enum NativeWindowSceneResizability: Equatable {
    case automatic
    case contentSize

    var swiftUIValue: WindowResizability {
        switch self {
        case .automatic:
            return .automatic
        case .contentSize:
            return .contentSize
        }
    }
}

package enum NativeWindowSceneRestorationPolicy: Equatable {
    case automatic
    case disabled
}

package enum NativeWindowSceneLaunchPolicy: Equatable {
    case automatic
    case presented
    case suppressed
}

package struct NativeWindowScenePolicy: Equatable {
    package let route: NativeWindowRoute
    package let defaultSize: CGSize
    package let minimumSize: CGSize
    package let resizability: NativeWindowSceneResizability
    package let restorationPolicy: NativeWindowSceneRestorationPolicy
    package let launchPolicy: NativeWindowSceneLaunchPolicy
    package let usesDefaultPlacement: Bool
    package let usesIdealPlacement: Bool

    package static func policy(for route: NativeWindowRoute) -> NativeWindowScenePolicy {
        switch route {
        case .mainWorkspace:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1180, height: 760),
                minimumSize: CGSize(width: 1180, height: 760),
                resizability: .automatic,
                restorationPolicy: .automatic,
                launchPolicy: .presented,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .library:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1240, height: 780),
                minimumSize: CGSize(width: 980, height: 640),
                resizability: .automatic,
                restorationPolicy: .automatic,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .evidenceWorkbench:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 920, height: 640),
                minimumSize: CGSize(width: 760, height: 520),
                resizability: .automatic,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .sourceReader:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1080, height: 760),
                minimumSize: CGSize(width: 860, height: 620),
                resizability: .automatic,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .settings:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 980, height: 720),
                minimumSize: CGSize(width: 780, height: 560),
                resizability: .automatic,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .taskCenter:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                minimumSize: CGSize(width: 560, height: 420),
                resizability: .contentSize,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .updatePrompt:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                minimumSize: CGSize(width: 560, height: 420),
                resizability: .contentSize,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .about:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 460, height: 360),
                minimumSize: CGSize(width: 460, height: 360),
                resizability: .contentSize,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .help:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 520, height: 420),
                minimumSize: CGSize(width: 520, height: 420),
                resizability: .contentSize,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        case .releaseNotes:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                minimumSize: CGSize(width: 560, height: 420),
                resizability: .contentSize,
                restorationPolicy: .disabled,
                launchPolicy: .suppressed,
                usesDefaultPlacement: true,
                usesIdealPlacement: true
            )
        }
    }
}
