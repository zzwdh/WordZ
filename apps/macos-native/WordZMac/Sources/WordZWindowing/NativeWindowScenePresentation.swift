import SwiftUI

// Scene-level policy owns only the defaults SwiftUI can express at scene construction time.
// NSWindow registration, restoration, and chrome stay in bindWindowRoute.
package struct NativeWindowScenePresentation {
    let route: NativeWindowRoute

    @MainActor
    package func apply<Content: Scene>(to scene: Content) -> some Scene {
        let policy = NativeWindowScenePolicy.policy(for: route)
        return scene
            .defaultSize(width: policy.defaultSize.width, height: policy.defaultSize.height)
            .windowResizability(policy.resizability.swiftUIValue)
    }
}

extension Scene {
    package func nativeWindowScenePresentation(_ route: NativeWindowRoute) -> some Scene {
        NativeWindowScenePresentation(route: route).apply(to: self)
    }
}
