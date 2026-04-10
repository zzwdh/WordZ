import Foundation

@MainActor
struct DiagnosticsDomainFactory {
    func makeDiagnosticsBundleService() -> any NativeDiagnosticsBundleServicing {
        NativeDiagnosticsBundleService()
    }
}

