import SwiftUI

struct SettingsPaneView: View {
    @Environment(\.wordZLanguageMode) var languageMode
    @ObservedObject var settings: WorkspaceSettingsViewModel
    let onAction: (SettingsPaneAction) -> Void

    @State var selectedSection: SettingsSection? = .workspace

    var body: some View {
        HSplitView {
            settingsSectionList
            settingsDetailContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var settingsSectionList: some View {
        List(SettingsSection.allCases, selection: $selectedSection) { section in
            Label(section.title(in: languageMode), systemImage: section.symbolName)
                .tag(section)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 180, idealWidth: 190)
    }

    var settingsDetailContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                NativeWindowHeader(
                    title: t("设置", "Settings"),
                    subtitle: currentSection.title(in: languageMode)
                )

                sectionContent
                settingsSaveRow
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch currentSection {
        case .workspace:
            workspaceSection
        case .appearance:
            appearanceSection
        case .updates:
            updatesSection
        case .recent:
            recentSection
        case .support:
            supportSection
        case .about:
            aboutSection
        }
    }

    private var settingsSaveRow: some View {
        HStack {
            Spacer()
            Button(t("保存设置", "Save Settings")) { onAction(.save) }
                .buttonStyle(.borderedProminent)
        }
    }

    private var currentSection: SettingsSection {
        selectedSection ?? .workspace
    }
}
