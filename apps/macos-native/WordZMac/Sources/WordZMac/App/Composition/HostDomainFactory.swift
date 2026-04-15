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
        NativeHostActionService(
            dialogService: dialogService,
            sharingService: NativeSharingService(anchorWindowProvider: {
                NativeWindowRouting.window(for: .mainWorkspace)
            })
        )
    }

    func makeUpdateService() -> any NativeUpdateServicing {
        GitHubReleaseUpdateService(downloadsDirectoryProvider: {
            EnginePaths.defaultUserDataURL()
                .appendingPathComponent("downloads", isDirectory: true)
                .appendingPathComponent("updates", isDirectory: true)
        })
    }

    func makeNotificationService() -> any NativeNotificationServicing {
        if !NativeNotificationEnvironment.supportsUserNotifications {
            return NoOpNotificationService()
        }
        return NativeNotificationService()
    }

    func makeApplicationActivityInspector() -> any ApplicationActivityInspecting {
        NativeApplicationActivityInspector()
    }

    func makeBuildMetadataProvider() -> any NativeBuildMetadataProviding {
        NativeBuildMetadataService()
    }

    func makeQuickLookPreviewFileService() -> any QuickLookPreviewFilePreparing {
        QuickLookPreviewFileService()
    }
}
