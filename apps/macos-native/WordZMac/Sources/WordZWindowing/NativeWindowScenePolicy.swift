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

package struct NativeWindowScenePolicy: Equatable {
    package let route: NativeWindowRoute
    package let defaultSize: CGSize
    package let resizability: NativeWindowSceneResizability

    package static func policy(for route: NativeWindowRoute) -> NativeWindowScenePolicy {
        switch route {
        case .mainWorkspace:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1180, height: 760),
                resizability: .automatic
            )
        case .library:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1120, height: 760),
                resizability: .automatic
            )
        case .evidenceWorkbench:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 920, height: 640),
                resizability: .automatic
            )
        case .sourceReader:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 1080, height: 760),
                resizability: .automatic
            )
        case .settings:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 980, height: 720),
                resizability: .automatic
            )
        case .taskCenter:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                resizability: .contentSize
            )
        case .updatePrompt:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                resizability: .contentSize
            )
        case .about:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 460, height: 360),
                resizability: .contentSize
            )
        case .help:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 520, height: 420),
                resizability: .contentSize
            )
        case .releaseNotes:
            return NativeWindowScenePolicy(
                route: route,
                defaultSize: CGSize(width: 560, height: 420),
                resizability: .contentSize
            )
        }
    }
}
