import SwiftUI

/// Root window combining Windows Explorer sidebar/toolbar/inspector with
/// Norton Commander dual-pane layout, integrated shell prompt, and F3-F10 key bar.
struct MainWindowView: View {
    @ObservedObject var commander: CommanderViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Optional transient status toast
            if let status = commander.statusBanner {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(Color.accentColor)
                    Text(status)
                        .font(.system(size: 11.5, weight: .medium))
                    Spacer()
                    Button {
                        commander.statusBanner = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.14))
                Divider()
            }

            // Main content area: Sidebar + Panes + Inspector
            HSplitView {
                if commander.showSidebar {
                    SidebarTreeView(commander: commander)
                }

                if commander.layoutMode == .dualPane {
                    HSplitView {
                        FilePaneView(
                            commander: commander,
                            pane: commander.leftPane,
                            isActive: commander.activePaneSide == .left
                        )
                        .frame(minWidth: 320)

                        FilePaneView(
                            commander: commander,
                            pane: commander.rightPane,
                            isActive: commander.activePaneSide == .right
                        )
                        .frame(minWidth: 320)
                    }
                } else {
                    FilePaneView(
                        commander: commander,
                        pane: commander.activePane,
                        isActive: true
                    )
                    .frame(minWidth: 420)
                }

                if commander.showInspector {
                    PreviewInspectorView(
                        item: commander.activePane.cursorItem,
                        onViewFull: { commander.triggerViewFile() },
                        onEdit: { commander.triggerEditFile() }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if commander.showCommandLine {
                Divider()
                CommandLineBarView(commander: commander, shellRunner: commander.shellRunner)
            }

            Divider()
            FunctionKeyBarView(commander: commander)
        }
        .frame(minWidth: 960, minHeight: 620)
        .toolbar {
            mainToolbar
        }
        .sheet(item: $commander.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .alert("Operation Error", isPresented: Binding(
            get: { commander.alertError != nil },
            set: { if !$0 { commander.alertError = nil } }
        )) {
            Button("OK", role: .cancel) {
                commander.alertError = nil
            }
        } message: {
            Text(commander.alertError ?? "")
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var mainToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button {
                commander.showSidebar.toggle()
            } label: {
                Label("Sidebar", systemImage: "sidebar.left")
            }
            .help("Toggle Explorer Sidebar")

            Picker("Layout", selection: $commander.layoutMode) {
                Image(systemName: "rectangle.split.2x1").tag(LayoutMode.dualPane)
                Image(systemName: "rectangle").tag(LayoutMode.singlePane)
            }
            .pickerStyle(.segmented)
            .help("Switch between Dual-Pane (Norton Commander) and Single-Pane (Explorer)")
        }

        ToolbarItemGroup(placement: .automatic) {
            if commander.layoutMode == .dualPane {
                Button {
                    commander.swapPanes()
                } label: {
                    Label("Swap", systemImage: "arrow.left.arrow.right")
                }
                .help("Swap Left and Right Panes (⌘U)")

                Button {
                    commander.equalizePanes()
                } label: {
                    Label("Sync Panes", systemImage: "equal.square")
                }
                .help("Set Inactive Pane to Active Folder (⌘=)")

                Button {
                    if commander.isComparingDirectories {
                        commander.clearComparison()
                    } else {
                        commander.compareDirectories()
                    }
                } label: {
                    Label(
                        "Compare",
                        systemImage: commander.isComparingDirectories
                            ? "doc.on.doc.fill"
                            : "doc.on.doc"
                    )
                }
                .help("Compare Left and Right Directories (marks unique & newer files)")
            }

            Button {
                commander.triggerMakeDirectory()
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }
            .help("Create New Folder (F7)")

            Button {
                commander.triggerNewFile()
            } label: {
                Label("New File", systemImage: "doc.badge.plus")
            }
            .help("Create Empty File")

            Button {
                commander.showHiddenFiles.toggle()
            } label: {
                Label("Hidden", systemImage: commander.showHiddenFiles ? "eye.fill" : "eye.slash")
            }
            .help("Toggle Hidden Dotfiles (⌘⇧.)")

            Picker("Theme", selection: $commander.themeMode) {
                ForEach(AppThemeMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .frame(width: 155)
            .help("Switch between macOS Native, Norton Classic Blue, and Midnight Dark themes")

            Button {
                commander.showCommandLine.toggle()
            } label: {
                Label("Shell Bar", systemImage: "apple.terminal")
            }
            .help("Toggle Bottom Command Line")

            Button {
                commander.showInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle Explorer Preview Inspector")
        }
    }

    // MARK: - Sheet Routing

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .viewer(let item):
            FileViewerSheet(item: item)

        case .editor(let item):
            FileEditorSheet(item: item) {
                commander.refreshAll()
                commander.showStatus("Saved \"\(item.name)\"")
            }

        case .copy(let items, let destination):
            TransferOperationSheet(
                title: "Copy Items (F5)",
                verb: "Copy",
                items: items,
                initialDestination: destination
            ) { destPath, overwrite in
                commander.performCopy(items: items, to: destPath, overwrite: overwrite)
            }

        case .move(let items, let destination):
            TransferOperationSheet(
                title: "Move Items (F6)",
                verb: "Move",
                items: items,
                initialDestination: destination
            ) { destPath, overwrite in
                commander.performMove(items: items, to: destPath, overwrite: overwrite)
            }

        case .rename(let item):
            SingleInputSheet(
                title: "Rename Item",
                subtitle: "Current path: \(item.url.path)",
                placeholder: "New name",
                initialValue: item.name,
                confirmLabel: "Rename"
            ) { newName in
                commander.performRename(item: item, newName: newName)
            }

        case .makeDirectory(let parent):
            SingleInputSheet(
                title: "Create New Folder (F7)",
                subtitle: "In: \(parent.path)",
                placeholder: "Folder name (supports nested paths like a/b)",
                initialValue: "",
                confirmLabel: "Create Folder"
            ) { name in
                commander.performCreateDirectory(name: name, in: parent)
            }

        case .newFile(let parent):
            SingleInputSheet(
                title: "Create New File",
                subtitle: "In: \(parent.path)",
                placeholder: "Filename (e.g. notes.txt)",
                initialValue: "",
                confirmLabel: "Create File"
            ) { name in
                commander.performCreateFile(name: name, in: parent)
            }

        case .delete(let items):
            DeleteConfirmationSheet(items: items) { permanent in
                commander.performDelete(items: items, permanent: permanent)
            }

        case .wildcard(let select):
            SingleInputSheet(
                title: select ? "Select Files by Wildcard (+)" : "Deselect Files by Wildcard (-)",
                subtitle: "Use * and ? wildcards (e.g. *.swift, report_?.pdf)",
                placeholder: "*.*",
                initialValue: "*.*",
                confirmLabel: select ? "Select Matching" : "Deselect Matching"
            ) { pattern in
                commander.activePane.applyWildcard(pattern: pattern, select: select)
                commander.showStatus("\(select ? "Selected" : "Deselected") items matching \"\(pattern)\"")
            }

        case .properties(let item):
            PropertiesSheet(
                item: item,
                onCopyPath: { commander.copyPathToClipboard(item) },
                onRevealInFinder: { commander.revealInFinder(item) },
                onOpenTerminal: {
                    let targetDir = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
                    FileSystemService.shared.openInTerminal(directory: targetDir)
                }
            )
        }
    }
}
