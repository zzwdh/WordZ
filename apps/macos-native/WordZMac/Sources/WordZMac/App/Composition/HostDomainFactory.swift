import Foundation

@MainActor
struct HostDomainFactory {
    func makeDialogService() -> NativeDialogServicing {
        NativeSheetDialogService()
    }

    func makeHostPreferencesStore() -> any NativeHostPreferencesStoring {
        NativeHostPreferencesStore()
    }

    func makeHostActionService(dialogService: NativeDialogServicing) -> any NativeHostActionServicing {
        NativeHostActionService(dialogService: dialogService)
    }

    func makeUpdateService() -> any NativeUpdateServicing {
        GitHubReleaseUpdateService()
    }

    func makeNotificationService() -> any NativeNotificationServicing {
        if !NativeNotificationEnvironment.supportsUserNotifications {
            return NoOpNotificationService()
        }
        return NativeNotificationService()
    }

    func makeBuildMetadataProvider() -> any NativeBuildMetadataProviding {
        NativeBuildMetadataService()
    }
}

