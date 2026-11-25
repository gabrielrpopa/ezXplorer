import SwiftUI

/// Native macOS Menu Bar commands exposing both Norton Commander and Windows Explorer shortcuts.
struct AppCommands: Commands {
    @ObservedObject var commander: CommanderViewModel

    var body: some Commands {
        CommandMenu("Commander") {
            Button("Switch Active Pane") {
                commander.switchActivePane()
            }

            Button("Swap Left & Right Panes") {
                commander.swapPanes()
            }
            .keyboardShortcut("u", modifiers: .command)

            Button("Equalize Panes (Sync to Active)") {
                commander.equalizePanes()
            }
            .keyboardShortcut("=", modifiers: .command)

            Button("Compare Directories") {
                commander.compareDirectories()
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])

            Divider()

            Button("View File (F3)") {
                commander.triggerViewFile()
            }

            Button("Edit File (F4)") {
                commander.triggerEditFile()
            }

            Button("Copy to Other Pane (F5)") {
                commander.triggerCopy()
            }

            Button("Move to Other Pane (F6)") {
                commander.triggerMove()
            }

            Button("Rename (F2)") {
                commander.beginInlineRename(in: commander.activePane)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("New Folder (Inline)") {
                commander.createNewFolderInline(in: commander.activePane)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("New Folder Dialog (F7)...") {
                commander.triggerMakeDirectory()
            }

            Button("New File...") {
                commander.triggerNewFile()
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button("Delete / Move to Trash (F8)...") {
                commander.triggerDelete()
            }

            Divider()

            Button("Cut Selected Items") {
                commander.cutSelectionToClipboard(from: commander.activePane)
            }

            Button("Copy Selected Items to Clipboard") {
                commander.copySelectionToClipboard(from: commander.activePane)
            }

            Button("Paste Items into Active Pane") {
                commander.pasteFromClipboard(into: commander.activePane)
            }

            Button("Compress Selection to ZIP") {
                commander.compressSelection(in: commander.activePane)
            }

            Button("Calculate Folder Size") {
                commander.calculateSelectedFolderSize(in: commander.activePane)
            }

            Button("Properties / Get Info") {
                commander.triggerProperties(in: commander.activePane)
            }
            .keyboardShortcut("i", modifiers: .command)

            Divider()

            Button("Select All in Active Pane") {
                commander.activePane.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)

            Button("Clear Selection") {
                commander.activePane.clearSelection()
            }

            Button("Invert Selection") {
                commander.activePane.invertSelection()
            }

            Button("Select by Wildcard (+)...") {
                commander.triggerWildcardSelection(select: true)
            }

            Button("Deselect by Wildcard (-)...") {
                commander.triggerWildcardSelection(select: false)
            }

            Divider()

            Button("Open Active Folder in Terminal (F9)") {
                commander.triggerOpenTerminal()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])

            Button("Bookmark Active Folder") {
                commander.addActiveFolderToFavorites()
            }
            .keyboardShortcut("b", modifiers: .command)

            Button("Refresh All Panes") {
                commander.refreshAll()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }

        CommandMenu("Explorer View") {
            Picker("Layout Mode", selection: $commander.layoutMode) {
                ForEach(LayoutMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Picker("Theme", selection: $commander.themeMode) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Divider()

            Toggle("Show Sidebar Tree", isOn: $commander.showSidebar)
                .keyboardShortcut("s", modifiers: [.command, .option])

            Toggle("Show Preview Inspector", isOn: $commander.showInspector)
                .keyboardShortcut("p", modifiers: [.command, .option])

            Toggle("Show Integrated Command Line", isOn: $commander.showCommandLine)
                .keyboardShortcut("k", modifiers: [.command, .option])

            Toggle("Show Hidden Files", isOn: $commander.showHiddenFiles)
                .keyboardShortcut(".", modifiers: [.command, .shift])
        }
    }
}
