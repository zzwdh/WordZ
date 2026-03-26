import SwiftUI

@main
struct WordZMacApp: App {
    var body: some Scene {
        WindowGroup {
            RootContentView()
                .frame(minWidth: 1180, minHeight: 760)
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            SidebarCommands()
        }
    }
}
