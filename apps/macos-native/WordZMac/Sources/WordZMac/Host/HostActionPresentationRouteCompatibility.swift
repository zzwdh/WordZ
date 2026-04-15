extension NativeWindowRoute {
    package var hostPresentationHint: NativePresentationRouteHint {
        NativePresentationRouteHint(id: id)
    }
}

extension NativePresentationRouteHint {
    package var nativeWindowRoute: NativeWindowRoute? {
        NativeWindowRoute(rawValue: id)
    }
}
