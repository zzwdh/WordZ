import Foundation

@MainActor
struct NativeAppLiveComposition {
    let engine: EngineDomainFactory
    let storage: StorageDomainFactory
    let host: HostDomainFactory
    let export: ExportDomainFactory
    let diagnostics: DiagnosticsDomainFactory
    let workspace: WorkspaceDomainFactory

    static func live() -> NativeAppLiveComposition {
        NativeAppLiveComposition(
            engine: EngineDomainFactory(),
            storage: StorageDomainFactory(),
            host: HostDomainFactory(),
            export: ExportDomainFactory(),
            diagnostics: DiagnosticsDomainFactory(),
            workspace: WorkspaceDomainFactory()
        )
    }
}
