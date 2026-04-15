import AppKit
import XCTest
import WordZHost
@testable import WordZWorkspaceCore

@MainActor
final class NativeSheetDialogServiceTests: XCTestCase {
    func testChooseImportPathsBuildsHostOpenPanelRequestAndMapsPaths() async {
        let presenter = FakePanelPresenter()
        presenter.openPanelResult = [
            URL(fileURLWithPath: "/tmp/demo.txt"),
            URL(fileURLWithPath: "/tmp/demo.pdf")
        ]
        var capturedRoute: NativeWindowRoute?
        let service = NativeSheetDialogService(
            panelPresenter: presenter,
            presentationWindowProvider: { route in
                capturedRoute = route
                return nil
            }
        )

        let result = await service.chooseImportPaths(preferredRoute: .library)

        XCTAssertEqual(result, ["/tmp/demo.txt", "/tmp/demo.pdf"])
        XCTAssertEqual(capturedRoute, .library)
        XCTAssertEqual(
            presenter.lastOpenPanelRequest,
            NativeOpenPanelRequest(
                title: "导入语料",
                message: "选择要导入的 TXT、DOCX、PDF 文件或文件夹（文件夹会递归扫描）",
                canChooseFiles: true,
                canChooseDirectories: true,
                allowsMultipleSelection: true,
                canCreateDirectories: false,
                allowedExtensions: ImportedDocumentReadingSupport.supportedImportExtensions
            )
        )
    }

    func testChooseExportFormatMapsAlertButtonSelectionToTableFormat() async {
        let presenter = FakePanelPresenter()
        presenter.alertResult = .button(index: 1)
        let service = NativeSheetDialogService(panelPresenter: presenter)

        let format = await service.chooseExportFormat(preferredRoute: .settings)

        XCTAssertEqual(format, .csv)
        XCTAssertEqual(
            presenter.lastAlertRequest,
            NativeAlertRequest(
                messageText: "选择导出格式",
                informativeText: "你可以导出为 Excel（.xlsx）或 CSV（.csv）。",
                buttons: ["Excel (.xlsx)", "CSV (.csv)", "取消"]
            )
        )
    }

    func testConfirmBuildsWarningAlertAndUsesPreferredRoute() async {
        let presenter = FakePanelPresenter()
        presenter.alertResult = .button(index: 0)
        var capturedRoute: NativeWindowRoute?
        let service = NativeSheetDialogService(
            panelPresenter: presenter,
            presentationWindowProvider: { route in
                capturedRoute = route
                return nil
            }
        )

        let confirmed = await service.confirm(
            title: "删除语料集",
            message: "此操作无法撤销。",
            confirmTitle: "删除",
            preferredRoute: .mainWorkspace
        )

        XCTAssertTrue(confirmed)
        XCTAssertEqual(capturedRoute, .mainWorkspace)
        XCTAssertEqual(
            presenter.lastAlertRequest,
            NativeAlertRequest(
                messageText: "删除语料集",
                informativeText: "此操作无法撤销。",
                style: .warning,
                buttons: ["删除", "取消"]
            )
        )
    }
}

@MainActor
private final class FakePanelPresenter: NativeDialogPanelPresenting {
    var openPanelResult: [URL]?
    var savePanelResult: URL?
    var alertResult: NativeAlertSelection = .cancel
    var textPromptResult: String?

    var lastOpenPanelRequest: NativeOpenPanelRequest?
    var lastSavePanelRequest: NativeSavePanelRequest?
    var lastAlertRequest: NativeAlertRequest?
    var lastTextPromptRequest: NativeTextPromptRequest?

    func presentOpenPanel(_ request: NativeOpenPanelRequest, presentationWindow: NSWindow?) async -> [URL]? {
        lastOpenPanelRequest = request
        return openPanelResult
    }

    func presentSavePanel(_ request: NativeSavePanelRequest, presentationWindow: NSWindow?) async -> URL? {
        lastSavePanelRequest = request
        return savePanelResult
    }

    func presentAlert(_ request: NativeAlertRequest, presentationWindow: NSWindow?) async -> NativeAlertSelection {
        lastAlertRequest = request
        return alertResult
    }

    func presentTextPrompt(_ request: NativeTextPromptRequest, presentationWindow: NSWindow?) async -> String? {
        lastTextPromptRequest = request
        return textPromptResult
    }
}
