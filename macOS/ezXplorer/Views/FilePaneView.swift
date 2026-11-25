import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Single file-browser panel combining Norton Commander keyboard/cursor/multi-select
/// with Windows Explorer sortable columns, native icons, drag-and-drop, and context menus.
struct FilePaneView: View {
    @ObservedObject var commander: CommanderViewModel
    @ObservedObject var pane: PaneViewModel
    let isActive: Bool

    @State private var isDropTargeted: Bool = false

    private var palette: ThemePalette { commander.palette }

    var body: some View {
        VStack(spacing: 0) {
            BreadcrumbBarView(
                pane: pane,
                isActive: isActive,
                palette: palette,
                onActivate: { commander.activatePane(pane.side) }
            )

            Divider()
                .overlay(palette.borderColor)

            PaneToolbarView(
                commander: commander,
                pane: pane,
                isActive: isActive
            )

            Divider()
                .overlay(palette.borderColor)

            columnHeaderBar

            Divider()
                .overlay(palette.borderColor)

            fileListBody

            Divider()
                .overlay(palette.borderColor)

            paneFooterBar
        }
        .background(isActive ? palette.paneBackground : palette.inactivePaneBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(
                    isDropTargeted ? Color.accentColor : (isActive ? palette.activeHeaderAccent : palette.borderColor),
                    lineWidth: isDropTargeted ? 2.5 : (isActive ? 1.5 : 0.5)
                )
        )
        .onTapGesture {
            commander.activatePane(pane.side)
        }
        .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
            handleProviders(providers)
        }
    }

    // MARK: - Sortable Column Headers

    private var columnHeaderBar: some View {
        HStack(spacing: 6) {
            sortHeaderButton(title: "Name", field: .name, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            sortHeaderButton(title: "Ext", field: .fileExtension, alignment: .leading)
                .frame(width: 54, alignment: .leading)

            sortHeaderButton(title: "Size", field: .size, alignment: .trailing)
                .frame(width: 82, alignment: .trailing)

            sortHeaderButton(title: "Modified", field: .date, alignment: .trailing)
                .frame(width: 118, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(palette.headerBackground.opacity(0.85))
    }

    private func sortHeaderButton(title: String, field: SortField, alignment: Alignment) -> some View {
        Button {
            commander.activatePane(pane.side)
            pane.setSort(field: field)
        } label: {
            HStack(spacing: 3) {
                if alignment == .trailing { Spacer(minLength: 0) }
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: palette.fontDesign))
                    .foregroundStyle(palette.isClassicTUI ? Color.yellow : Color.secondary)
                if pane.sortField == field {
                    Image(systemName: pane.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(palette.isClassicTUI ? Color.yellow : Color.accentColor)
                }
                if alignment == .leading { Spacer(minLength: 0) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scrollable File List

    private var fileListBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if let error = pane.errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundStyle(palette.isClassicTUI ? Color.white : Color.primary)
                            Spacer()
                        }
                        .padding(10)
                    }

                    let cutPaths = commander.cutItemPaths
                    ForEach(pane.filteredItems) { item in
                        let isRenamingThisRow = (pane.renamingItemID == item.id)
                        FileRowView(
                            item: item,
                            isCursor: isActive && pane.cursorID == item.id,
                            isInactiveCursor: !isActive && pane.cursorID == item.id,
                            isMarked: pane.selectedIDs.contains(item.id),
                            isCut: cutPaths.contains(item.url.standardizedFileURL.path),
                            isRenaming: isRenamingThisRow,
                            calculatedFolderSize: pane.calculatedFolderSizes[item.id],
                            compareStatus: pane.compareStatuses[item.id] ?? .none,
                            palette: palette,
                            onCommitRename: { newName in
                                commander.commitInlineRename(in: pane, item: item, newName: newName)
                            },
                            onCancelRename: {
                                pane.cancelInlineRename()
                            }
                        )
                        .id(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            guard !isRenamingThisRow else { return }
                            commander.activatePane(pane.side)
                            pane.selectSingle(item)
                            pane.openItem(item)
                        }
                        .onTapGesture(count: 1) {
                            guard !isRenamingThisRow else { return }
                            commander.activatePane(pane.side)
                            if NSEvent.modifierFlags.contains(.command) {
                                pane.toggleSelection(for: item)
                            } else {
                                pane.selectSingle(item)
                            }
                        }
                        .onDrag {
                            guard !item.isParentEntry && !isRenamingThisRow else { return NSItemProvider() }
                            return NSItemProvider(object: item.url as NSURL)
                        }
                        .contextMenu {
                            rowContextMenu(for: item)
                        }
                    }
                }
            }
            .onChange(of: pane.cursorID) { _, newCursor in
                guard let newCursor else { return }
                withAnimation(.linear(duration: 0.08)) {
                    proxy.scrollTo(newCursor)
                }
            }
        }
    }

    // MARK: - Context Menu (Explorer + Commander Actions)

    @ViewBuilder
    private func rowContextMenu(for item: FileItem) -> some View {
        Button("Open") {
            commander.activatePane(pane.side)
            pane.openItem(item)
        }

        if !item.isParentEntry && !item.isDirectory {
            Button("View (F3)") {
                commander.activatePane(pane.side)
                pane.selectSingle(item)
                commander.triggerViewFile()
            }
            Button("Edit (F4)") {
                commander.activatePane(pane.side)
                pane.selectSingle(item)
                commander.triggerEditFile()
            }
        }

        if !item.isParentEntry {
            Divider()

            Button("Cut") {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.cutSelectionToClipboard(from: pane)
            }

            Button("Copy") {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.copySelectionToClipboard(from: pane)
            }

            if commander.canPasteItems {
                Button("Paste Here") {
                    commander.pasteFromClipboard(into: pane)
                }
            }

            Divider()

            Button("Copy to Other Pane (F5)") {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.triggerCopy(from: pane)
            }

            Button("Move to Other Pane (F6)") {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.triggerMove(from: pane)
            }

            Button("Rename (F2)") {
                commander.beginInlineRename(in: pane, item: item)
            }

            Button("Duplicate") {
                commander.activatePane(pane.side)
                commander.performDuplicate(item: item)
            }

            Button("Compress to ZIP") {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.compressSelection(in: pane)
            }

            if !item.isDirectory && item.fileExtension.lowercased() == "zip" {
                Button("Extract ZIP Here") {
                    commander.activatePane(pane.side)
                    pane.selectSingle(item)
                    commander.extractSelectedZip(in: pane)
                }
            }

            Divider()

            if item.isDirectory {
                Button("Calculate Folder Size") {
                    commander.activatePane(pane.side)
                    if !pane.selectedIDs.contains(item.id) {
                        pane.selectSingle(item)
                    }
                    commander.calculateSelectedFolderSize(in: pane)
                }
            }

            Button("Properties / Get Info") {
                commander.triggerProperties(in: pane, item: item)
            }

            Button("Copy Full Path") {
                commander.copyPathToClipboard(item)
            }

            Button("Reveal in Finder") {
                commander.revealInFinder(item)
            }

            Button("Open Folder in Terminal") {
                let targetDir = item.isDirectory ? item.url : item.url.deletingLastPathComponent()
                FileSystemService.shared.openInTerminal(directory: targetDir)
            }

            Divider()

            Button("Delete / Move to Trash (F8)", role: .destructive) {
                commander.activatePane(pane.side)
                if !pane.selectedIDs.contains(item.id) {
                    pane.selectSingle(item)
                }
                commander.triggerDelete(in: pane)
            }
        }
    }

    // MARK: - Pane Status Footer

    private var paneFooterBar: some View {
        HStack(spacing: 10) {
            if !pane.selectedIDs.isEmpty {
                Text("Selected: \(pane.selectedIDs.count) (\(ByteCountFormatter.string(fromByteCount: pane.selectedBytes, countStyle: .file)))")
                    .font(.system(size: 11, weight: .semibold, design: palette.fontDesign))
                    .foregroundStyle(palette.selectedRowText)
            } else {
                Text("\(pane.totalFolders) folders, \(pane.totalFiles) files (\(ByteCountFormatter.string(fromByteCount: pane.totalBytes, countStyle: .file)))")
                    .font(.system(size: 11, design: palette.fontDesign))
                    .foregroundStyle(palette.isClassicTUI ? Color.white.opacity(0.85) : Color.secondary)
            }

            Spacer()

            if let freeSpace = pane.freeSpaceBytes {
                Text("Free: \(ByteCountFormatter.string(fromByteCount: freeSpace, countStyle: .file))")
                    .font(.system(size: 11, design: palette.fontDesign))
                    .foregroundStyle(palette.isClassicTUI ? Color.cyan : Color.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(palette.headerBackground.opacity(0.9))
    }

    // MARK: - Drop Handling

    private func handleProviders(_ providers: [NSItemProvider]) -> Bool {
        var collectedURLs: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            if provider.canLoadObject(ofClass: URL.self) {
                group.enter()
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    DispatchQueue.main.async {
                        if let url {
                            collectedURLs.append(url)
                        }
                        group.leave()
                    }
                }
            }
        }

        group.notify(queue: .main) {
            let shouldMove = NSEvent.modifierFlags.contains(.command)
            commander.handleFileDrop(urls: collectedURLs, onto: pane, move: shouldMove)
        }
        return !providers.isEmpty
    }
}

private struct FileRowView: View {
    let item: FileItem
    let isCursor: Bool
    let isInactiveCursor: Bool
    let isMarked: Bool
    let isCut: Bool
    let isRenaming: Bool
    let calculatedFolderSize: Int64?
    let compareStatus: CompareStatus
    let palette: ThemePalette
    let onCommitRename: (String) -> Void
    let onCancelRename: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // Selection indicator dot (classic NC mark feedback)
            Circle()
                .fill(isMarked ? palette.selectedRowText : Color.clear)
                .frame(width: 6, height: 6)

            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 15, height: 15)

            if isRenaming {
                InlineRenameTextField(
                    initialText: item.name,
                    isDirectory: item.isDirectory,
                    fontDesign: palette.fontDesign,
                    onCommit: onCommitRename,
                    onCancel: onCancelRename
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 19)
            } else {
                Text(item.name)
                    .font(.system(size: 12, weight: item.isDirectory ? .semibold : .regular, design: palette.fontDesign))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if compareStatus != .none {
                Text(compareStatus == .unique ? "NEW" : "MOD")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(compareStatus == .unique ? Color.green.opacity(0.35) : Color.blue.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }

            Text(item.fileExtension)
                .font(.system(size: 11.5, design: palette.fontDesign))
                .lineLimit(1)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 54, alignment: .leading)

            Text(displayedSize)
                .font(.system(size: 11.5, design: palette.fontDesign))
                .lineLimit(1)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 82, alignment: .trailing)

            Text(item.formattedDate)
                .font(.system(size: 11.5, design: palette.fontDesign))
                .lineLimit(1)
                .foregroundStyle(secondaryTextColor)
                .frame(width: 118, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .opacity(isCut ? 0.48 : 1.0)
        .background(rowBackground)
    }

    private var displayedSize: String {
        if item.isDirectory, !item.isParentEntry, let calculatedFolderSize {
            return ByteCountFormatter.string(fromByteCount: calculatedFolderSize, countStyle: .file)
        }
        return item.formattedSize
    }

    private var rowBackground: Color {
        if isCursor {
            return palette.cursorBackground
        }
        if isMarked {
            return palette.selectedRowBackground
        }
        switch compareStatus {
        case .unique:
            return palette.compareUniqueBackground
        case .newer:
            return palette.compareNewerBackground
        case .none:
            break
        }
        if isInactiveCursor {
            return palette.cursorBackground.opacity(0.35)
        }
        return Color.clear
    }

    private var textColor: Color {
        if isCursor {
            return isMarked ? palette.selectedRowText : palette.cursorText
        }
        if isMarked {
            return palette.selectedRowText
        }
        if item.isHidden {
            return palette.hiddenText
        }
        return item.isDirectory ? palette.directoryText : palette.rowText
    }

    private var secondaryTextColor: Color {
        if isCursor {
            return palette.cursorText.opacity(0.85)
        }
        if isMarked {
            return palette.selectedRowText.opacity(0.9)
        }
        return palette.isClassicTUI ? palette.rowText.opacity(0.8) : Color.secondary
    }
}
