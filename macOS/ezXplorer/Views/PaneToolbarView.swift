import SwiftUI

/// Per-pane icon command bar combining Windows 11 File Explorer actions
/// (New Folder with inline rename, typed New File menu, Cut/Copy/Paste, Rename, Delete,
/// Compress/Extract, Sort, Properties) with Norton Commander dual-pane actions (F3-F6, Selection tools).
struct PaneToolbarView: View {
    @ObservedObject var commander: CommanderViewModel
    @ObservedObject var pane: PaneViewModel
    let isActive: Bool

    private var palette: ThemePalette { commander.palette }

    private var hasSelection: Bool { pane.hasActionableSelection }
    private var hasCursorFile: Bool { pane.cursorIsFile }
    private var hasCursorItem: Bool {
        guard let item = pane.cursorItem else { return false }
        return !item.isParentEntry
    }
    private var isDualPane: Bool { commander.layoutMode == .dualPane }
    private var copyToOtherIcon: String {
        pane.side == .left ? "arrow.right.square" : "arrow.left.square"
    }
    private var moveToOtherIcon: String {
        pane.side == .left ? "arrowshape.turn.up.right" : "arrowshape.turn.up.left"
    }
    private var oppositePaneName: String {
        pane.side.opposite.displayName
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                // MARK: Group 1 — Create (Windows 11 style)
                toolbarIconButton(
                    systemImage: "folder.badge.plus",
                    tooltip: "Create New Folder — Creates a new folder ready to rename immediately",
                    enabled: true
                ) {
                    commander.createNewFolderInline(in: pane)
                }

                newFileMenu

                toolbarDivider

                // MARK: Group 2 — Clipboard, Rename & Delete (Windows 11)
                toolbarIconButton(
                    systemImage: "scissors",
                    tooltip: "Cut Selected Items — Move on Paste",
                    enabled: hasSelection
                ) {
                    commander.cutSelectionToClipboard(from: pane)
                }

                toolbarIconButton(
                    systemImage: "doc.on.doc",
                    tooltip: "Copy Selected Items to Clipboard",
                    enabled: hasSelection
                ) {
                    commander.copySelectionToClipboard(from: pane)
                }

                toolbarIconButton(
                    systemImage: "doc.on.clipboard",
                    tooltip: "Paste Items into This Folder",
                    enabled: commander.canPasteItems
                ) {
                    commander.pasteFromClipboard(into: pane)
                }

                toolbarIconButton(
                    systemImage: "character.cursor.ibeam",
                    tooltip: "Rename Selected Item Inline (F2)",
                    enabled: hasCursorItem
                ) {
                    commander.beginInlineRename(in: pane)
                }

                toolbarIconButton(
                    systemImage: "trash",
                    tooltip: "Delete Selected Folder or File (F8) — Opens confirmation dialog",
                    enabled: hasSelection,
                    isDestructive: true
                ) {
                    commander.triggerDelete(in: pane)
                }

                toolbarDivider

                // MARK: Group 3 — Norton Commander Dual-Pane & File Actions
                if isDualPane {
                    toolbarIconButton(
                        systemImage: copyToOtherIcon,
                        tooltip: "Copy Selected Items to \(oppositePaneName) (F5)",
                        enabled: hasSelection
                    ) {
                        commander.triggerCopy(from: pane)
                    }

                    toolbarIconButton(
                        systemImage: moveToOtherIcon,
                        tooltip: "Move Selected Items to \(oppositePaneName) (F6)",
                        enabled: hasSelection
                    ) {
                        commander.triggerMove(from: pane)
                    }
                }

                toolbarIconButton(
                    systemImage: "eye",
                    tooltip: "View Selected File (F3) — Text, Image, or Hex Dump",
                    enabled: hasCursorFile
                ) {
                    commander.triggerViewFile(in: pane)
                }

                toolbarIconButton(
                    systemImage: "square.and.pencil",
                    tooltip: "Edit Selected File (F4) — Built-in Text Editor",
                    enabled: hasCursorFile
                ) {
                    commander.triggerEditFile(in: pane)
                }

                toolbarDivider

                // MARK: Group 4 — Archive, Selection, Sort, Properties & More
                if pane.cursorIsZipArchive {
                    toolbarIconButton(
                        systemImage: "arrow.up.bin",
                        tooltip: "Extract ZIP Archive Here",
                        enabled: true
                    ) {
                        commander.extractSelectedZip(in: pane)
                    }
                }

                toolbarIconButton(
                    systemImage: "doc.zipper",
                    tooltip: "Compress Selected Items to ZIP Archive",
                    enabled: hasSelection
                ) {
                    commander.compressSelection(in: pane)
                }

                selectionMenu
                sortMenu

                toolbarIconButton(
                    systemImage: "info.circle",
                    tooltip: "Properties / Get Info for Selected Item",
                    enabled: hasCursorItem
                ) {
                    commander.triggerProperties(in: pane)
                }

                moreActionsMenu
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .background(palette.headerBackground.opacity(0.92))
    }

    // MARK: - New File Dropdown Menu

    private var newFileMenu: some View {
        Menu {
            ForEach(FileTemplateCategory.allCases) { category in
                Section(category.rawValue) {
                    ForEach(FileTemplate.templates(in: category)) { template in
                        Button {
                            commander.createNewFile(from: template, in: pane)
                        } label: {
                            Label(template.displayName, systemImage: template.systemImage)
                        }
                    }
                }
            }

            Divider()

            Button {
                commander.triggerNewFile(in: pane)
            } label: {
                Label("Custom File Name…", systemImage: "doc.badge.ellipsis")
            }
        } label: {
            PaneToolbarMenuIcon(
                systemImage: "doc.badge.plus",
                palette: palette,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Create New File — Choose a file type (Text, Markdown, RTF, CSV, Script, Code, JSON, ZIP, etc.)")
    }

    // MARK: - Selection Tools Menu (Norton Commander + Windows 11)

    private var selectionMenu: some View {
        Menu {
            Button {
                commander.activatePane(pane.side)
                pane.selectAll()
            } label: {
                Label("Select All (⌘A)", systemImage: "checkmark.circle.fill")
            }

            Button {
                commander.activatePane(pane.side)
                pane.clearSelection()
            } label: {
                Label("Clear Selection", systemImage: "circle")
            }
            .disabled(pane.selectedIDs.isEmpty)

            Button {
                commander.activatePane(pane.side)
                pane.invertSelection()
            } label: {
                Label("Invert Selection", systemImage: "arrow.triangle.2.circlepath")
            }

            Divider()

            Button {
                commander.activatePane(pane.side)
                commander.triggerWildcardSelection(select: true)
            } label: {
                Label("Select by Wildcard (+)…", systemImage: "plus.magnifyingglass")
            }

            Button {
                commander.activatePane(pane.side)
                commander.triggerWildcardSelection(select: false)
            } label: {
                Label("Deselect by Wildcard (-)…", systemImage: "minus.magnifyingglass")
            }
        } label: {
            PaneToolbarMenuIcon(
                systemImage: "checklist",
                palette: palette,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Selection Tools — Select All, Invert, or Wildcard Match (+/-)")
    }

    // MARK: - Sort Menu (Windows 11)

    private var sortMenu: some View {
        Menu {
            Section("Sort By") {
                ForEach(SortField.allCases) { field in
                    Button {
                        commander.activatePane(pane.side)
                        pane.setSort(field: field)
                    } label: {
                        HStack {
                            Text(field.rawValue)
                            if pane.sortField == field {
                                Image(systemName: pane.sortAscending ? "chevron.up" : "chevron.down")
                            }
                        }
                    }
                }
            }

            Divider()

            Button {
                commander.activatePane(pane.side)
                if !pane.sortAscending {
                    pane.sortAscending = true
                    pane.refresh()
                }
            } label: {
                Label("Ascending", systemImage: pane.sortAscending ? "checkmark" : "")
            }

            Button {
                commander.activatePane(pane.side)
                if pane.sortAscending {
                    pane.sortAscending = false
                    pane.refresh()
                }
            } label: {
                Label("Descending", systemImage: !pane.sortAscending ? "checkmark" : "")
            }
        } label: {
            PaneToolbarMenuIcon(
                systemImage: "arrow.up.arrow.down",
                palette: palette,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort Folder Contents (Name, Extension, Size, Modified)")
    }

    // MARK: - More Actions Menu (Explorer + Norton Commander Utilities)

    private var moreActionsMenu: some View {
        Menu {
            if let item = pane.cursorItem, !item.isParentEntry {
                Button {
                    commander.activatePane(pane.side)
                    commander.performDuplicate(item: item)
                } label: {
                    Label("Duplicate \"\(item.name)\"", systemImage: "plus.square.on.square")
                }

                Button {
                    commander.activatePane(pane.side)
                    commander.copyPathToClipboard(item)
                } label: {
                    Label("Copy as Path", systemImage: "link")
                }

                if item.isDirectory {
                    Button {
                        commander.calculateSelectedFolderSize(in: pane)
                    } label: {
                        Label("Calculate Folder Size", systemImage: "sum")
                    }
                }

                if pane.cursorIsZipArchive {
                    Button {
                        commander.extractSelectedZip(in: pane)
                    } label: {
                        Label("Extract ZIP Archive Here", systemImage: "arrow.up.bin")
                    }
                }

                Button {
                    commander.revealInFinder(item)
                } label: {
                    Label("Reveal in Finder", systemImage: "macwindow")
                }

                Divider()
            }

            Button {
                commander.activatePane(pane.side)
                FileSystemService.shared.openInTerminal(directory: pane.currentURL)
                commander.showStatus("Opened Terminal in \(pane.currentURL.lastPathComponent)")
            } label: {
                Label("Open Folder in Terminal (F9)", systemImage: "terminal")
            }

            Button {
                commander.activatePane(pane.side)
                commander.addActiveFolderToFavorites()
            } label: {
                Label("Pin Folder to Favorites (⌘B)", systemImage: "star")
            }

            if isDualPane {
                Divider()

                Button {
                    commander.activatePane(pane.side)
                    commander.equalizePanes()
                } label: {
                    Label("Sync \(oppositePaneName) to This Folder (⌘=)", systemImage: "equal.square")
                }

                Button {
                    commander.compareDirectories()
                } label: {
                    Label("Compare Left & Right Folders", systemImage: "doc.on.doc")
                }
            }
        } label: {
            PaneToolbarMenuIcon(
                systemImage: "ellipsis.circle",
                palette: palette,
                isActive: isActive
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("More Folder & File Actions (Duplicate, Copy Path, Folder Size, Finder, Terminal, Pin)")
    }

    // MARK: - Helpers

    private var toolbarDivider: some View {
        Rectangle()
            .fill(palette.borderColor.opacity(0.75))
            .frame(width: 1, height: 15)
            .padding(.horizontal, 3)
    }

    private func toolbarIconButton(
        systemImage: String,
        tooltip: String,
        enabled: Bool,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        PaneToolbarActionButton(
            systemImage: systemImage,
            tooltip: tooltip,
            enabled: enabled,
            isDestructive: isDestructive,
            palette: palette,
            action: action
        )
    }
}

private struct PaneToolbarActionButton: View {
    let systemImage: String
    let tooltip: String
    let enabled: Bool
    let isDestructive: Bool
    let palette: ThemePalette
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(iconColor)
                .frame(width: 24, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isHovered && enabled ? hoverBackground : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering in
            isHovered = hovering
        }
        .help(tooltip)
    }

    private var iconColor: Color {
        guard enabled else {
            return palette.isClassicTUI ? Color.white.opacity(0.28) : Color.secondary.opacity(0.38)
        }
        if isDestructive {
            return palette.isClassicTUI ? Color(red: 1.0, green: 0.45, blue: 0.45) : Color.red
        }
        return palette.isClassicTUI ? Color.white : Color.primary
    }

    private var hoverBackground: Color {
        if isDestructive {
            return Color.red.opacity(0.16)
        }
        return palette.isClassicTUI ? Color.white.opacity(0.16) : Color.primary.opacity(0.09)
    }
}

private struct PaneToolbarMenuIcon: View {
    let systemImage: String
    let palette: ThemePalette
    let isActive: Bool

    @State private var isHovered: Bool = false

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundStyle(palette.isClassicTUI ? Color.white : Color.primary)
            .frame(width: 24, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? (palette.isClassicTUI ? Color.white.opacity(0.16) : Color.primary.opacity(0.09)) : Color.clear)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
