import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class LocalizationSupportTests: XCTestCase {
    func testLocalizedResourceLookupUsesStringsTables() {
        XCTAssertEqual(
            WordZLocalization.text(forKey: "语料库", table: "Windows", mode: .english, fallback: "Library"),
            "Library"
        )
        XCTAssertEqual(
            WordZLocalization.text(forKey: "语料库", table: "Windows", mode: .chinese, fallback: "Library"),
            "语料库"
        )
    }

    func testLocalizedFormattingUsesTranslatedTemplate() {
        XCTAssertEqual(
            WordZLocalization.formatted(
                forKey: "已创建文件夹“%@”。",
                table: "Errors",
                mode: .english,
                fallback: "Created folder \"%@\".",
                arguments: ["Demo"]
            ),
            "Created folder \"Demo\"."
        )
        XCTAssertEqual(
            WordZLocalization.formatted(
                forKey: "已创建文件夹“%@”。",
                table: "Errors",
                mode: .chinese,
                fallback: "Created folder \"%@\".",
                arguments: ["示例"]
            ),
            "已创建文件夹“示例”。"
        )
    }

    func testPreferredLanguageNormalizationAlwaysUsesSystemMode() {
        XCTAssertEqual(WordZLocalization.normalizedPreferredMode(.system), .system)
        XCTAssertEqual(WordZLocalization.normalizedPreferredMode(.english), .system)
        XCTAssertEqual(WordZLocalization.normalizedPreferredMode(.chinese), .system)
    }

    func testWindowRouteTitlesReadLocalizedResources() {
        XCTAssertEqual(NativeWindowRoute.help.title(in: .english), "Usage Guide")
        XCTAssertEqual(NativeWindowRoute.help.title(in: .chinese), "使用说明")
        XCTAssertEqual(NativeWindowRoute.sourceReader.title(in: .english), "Source Reader")
        XCTAssertEqual(NativeWindowRoute.sourceReader.title(in: .chinese), "原文阅读器")
    }
}
