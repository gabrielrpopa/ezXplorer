import SwiftUI

@main
struct ezXplorerApp: App {
    @StateObject private var commander = CommanderViewModel()

    var body: some Scene {
        WindowGroup("ezXplorer") {
            MainWindowView(commander: commander)
        }
        .defaultSize(width: 1280, height: 780)
        .commands {
            AppCommands(commander: commander)
        }
    }
}
