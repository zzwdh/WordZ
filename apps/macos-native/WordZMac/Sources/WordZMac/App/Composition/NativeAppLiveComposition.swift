import Foundation

@MainActor
struct NativeAppLiveComposition {
    let storage: StorageDomainFactory
    let host: HostDomainFactory
    let export: ExportDomainFactory
    let diagnostics: DiagnosticsDomainFactory
    let workspace: WorkspaceDomainFactory

    static func live() -> NativeAppLiveComposition {
        NativeAppLiveComposition(
            storage: StorageDomainFactory(),
            host: HostDomainFactory(),
            export: ExportDomainFactory(),
            diagnostics: DiagnosticsDomainFactory(),
            workspace: WorkspaceDomainFactory()
        )
    }
}
