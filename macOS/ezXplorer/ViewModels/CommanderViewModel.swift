import Foundation
import SwiftUI
import AppKit
import Combine

enum ClipboardMode {
    case copy
    case cut
}

struct FileClipboard {
    let urls: [URL]
    let mode: ClipboardMode
}

enum ActiveSheet: Identifiable {
    case viewer(FileItem)
    case editor(FileItem)
    case copy(items: [FileItem], destination: URL)
    case move(items: [FileItem], destination: URL)
    case rename(FileItem)
    case makeDirectory(parent: URL)
    case newFile(parent: URL)
    case delete(items: [FileItem])
    case wildcard(select: Bool)
    case properties(FileItem)

    var id: String {
        switch self {
        case .viewer(let item): return "viewer-\(item.id)"
        case .editor(let item): return "editor-\(item.id)"
        case .copy(_, let dest): return "copy-\(dest.path)"
        case .move(_, let dest): return "move-\(dest.path)"
        case .rename(let item): return "rename-\(item.id)"
        case .makeDirectory(let parent): return "mkdir-\(parent.path)"
        case .newFile(let parent): return "newfile-\(parent.path)"
        case .delete(let items): return "delete-\(items.count)"
        case .wildcard(let select): return "wildcard-\(select)"
        case .properties(let item): return "properties-\(item.id)"
        }
    }
}

/// Top-level coordinator unifying dual-pane Norton Commander workflows with Windows Explorer navigation.
@MainActor
final class CommanderViewModel: ObservableObject {
    @Published var leftPane: PaneViewModel
    @Published var rightPane: PaneViewModel
    @Published var activePaneSide: PaneSide = .left

    @Published var layoutMode: LayoutMode = .dualPane
    @Published var themeMode: AppThemeMode = .system
    @Published var showSidebar: Bool = true
    @Published var showInspector: Bool = false
    @Published var showCommandLine: Bool = true
    @Published var showHiddenFiles: Bool = false {
        didSet {
            leftPane.showHidden = showHiddenFiles
            rightPane.showHidden = showHiddenFiles
            leftPane.refresh()
            rightPane.refresh()
        }
    }

    @Published var quickAccess: [QuickAccessLocation] = []
    @Published var volumes: [QuickAccessLocation] = []
    @Published var favorites: [QuickAccessLocation] = []
    @Published var treeRoots: [DirectoryTreeNode] = []

    @Published var activeSheet: ActiveSheet?
    @Published var statusBanner: String?
    @Published var alertError: String?
    @Published var isComparingDirectories: Bool = false
    @Published var fileClipboard: FileClipboard?

    let shellRunner = ShellCommandRunner()
    private let service = FileSystemService.shared
    private let keyboardMonitor = KeyboardMonitor()
    private let favoritesStorageKey = "ezXplorer.Favorites"
    private var bannerClearTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? home

        self.leftPane = PaneViewModel(side: .left, initialURL: home)
        self.rightPane = PaneViewModel(side: .right, initialURL: documents)

        // Forward nested pane changes so Sidebar, Preview Inspector, and Command Line stay in sync.
        leftPane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        rightPane.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        refreshSidebarLocations()
        loadFavorites()
        setupKeyboardMonitor()
    }

    var activePane: PaneViewModel {
        activePaneSide == .left ? leftPane : rightPane
    }

    var inactivePane: PaneViewModel {
        activePaneSide == .left ? rightPane : leftPane
    }

    var palette: ThemePalette {
        themeMode.palette
    }

    func pane(for side: PaneSide) -> PaneViewModel {
        side == .left ? leftPane : rightPane
    }

    func activatePane(_ side: PaneSide) {
        activePaneSide = side
    }

    func switchActivePane() {
        guard layoutMode == .dualPane else { return }
        activePaneSide = activePaneSide.opposite
    }

    func swapPanes() {
        guard layoutMode == .dualPane else { return }
        let leftURL = leftPane.currentURL
        let rightURL = rightPane.currentURL
        leftPane.navigate(to: rightURL)
        rightPane.navigate(to: leftURL)
        showStatus("Swapped Left and Right panes")
    }

    func equalizePanes() {
        guard layoutMode == .dualPane else { return }
        inactivePane.navigate(to: activePane.currentURL)
        showStatus("Synced \(inactivePane.side.displayName) to \(activePane.currentURL.lastPathComponent)")
    }

    func refreshAll() {
        leftPane.refresh()
        rightPane.refresh()
        refreshSidebarLocations()
        if isComparingDirectories {
            compareDirectories()
        }
    }

    func refreshSidebarLocations() {
        quickAccess = service.quickAccessLocations()
        volumes = service.mountedVolumes()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let root = URL(fileURLWithPath: "/")
        if treeRoots.isEmpty {
            let homeNode = DirectoryTreeNode(url: home, name: home.lastPathComponent, systemImage: "house.fill")
            homeNode.loadChildren(showHidden: showHiddenFiles)
            homeNode.isExpanded = true
            let rootNode = DirectoryTreeNode(url: root, name: "Macintosh HD", systemImage: "internaldrive.fill")
            treeRoots = [homeNode, rootNode]
        }
    }

    // MARK: - Favorites

    func addActiveFolderToFavorites() {
        let url = activePane.currentURL
        if favorites.contains(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) {
            showStatus("\"\(url.lastPathComponent)\" is already in Favorites")
            return
        }
        let fav = QuickAccessLocation(
            title: url.path == "/" ? "Root (/)" : url.lastPathComponent,
            url: url,
            systemImage: "star.fill"
        )
        favorites.append(fav)
        saveFavorites()
        showStatus("Added \"\(fav.title)\" to Favorites")
    }

    func removeFavorite(_ fav: QuickAccessLocation) {
        favorites.removeAll(where: { $0.id == fav.id })
        saveFavorites()
    }

    private func loadFavorites() {
        let paths = UserDefaults.standard.stringArray(forKey: favoritesStorageKey) ?? []
        favorites = paths.compactMap { path in
            let url = URL(fileURLWithPath: path)
            guard FileManager.default.fileExists(atPath: path) else { return nil }
            return QuickAccessLocation(
                title: url.path == "/" ? "Root (/)" : url.lastPathComponent,
                url: url,
                systemImage: "star.fill"
            )
        }
    }

    private func saveFavorites() {
        let paths = favorites.map(\.url.path)
        UserDefaults.standard.set(paths, forKey: favoritesStorageKey)
    }

    // MARK: - Directory Compare (Classic NC Feature)

    func compareDirectories() {
        guard layoutMode == .dualPane else {
            showStatus("Switch to Dual Pane mode to compare directories")
            return
        }
        let result = service.compareDirectories(leftItems: leftPane.items, rightItems: rightPane.items)
        leftPane.compareStatuses = result.leftStatuses
        rightPane.compareStatuses = result.rightStatuses
        isComparingDirectories = true

        // Also mark unique/newer items so F5 can immediately synchronize them!
        leftPane.selectedIDs = Set(result.leftStatuses.keys)
        rightPane.selectedIDs = Set(result.rightStatuses.keys)

        let totalDiffs = result.leftStatuses.count + result.rightStatuses.count
        if totalDiffs == 0 {
            showStatus("Directories match (no unique or newer files)")
        } else {
            showStatus("Compare found \(result.leftStatuses.count) on Left, \(result.rightStatuses.count) on Right")
        }
    }

    func clearComparison() {
        leftPane.compareStatuses.removeAll()
        rightPane.compareStatuses.removeAll()
        isComparingDirectories = false
        showStatus("Cleared directory comparison")
    }

    // MARK: - Windows 11 & Norton Commander Per-Pane Actions

    var cutItemPaths: Set<String> {
        guard let clip = fileClipboard, clip.mode == .cut else { return [] }
        return Set(clip.urls.map { $0.standardizedFileURL.path })
    }

    var canPasteItems: Bool {
        if let clip = fileClipboard, !clip.urls.isEmpty {
            return true
        }
        return !(systemPasteboardFileURLs().isEmpty)
    }

    private func systemPasteboardFileURLs() -> [URL] {
        let pb = NSPasteboard.general
        let objects = pb.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] ?? []
        return objects.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    /// Creates a new folder with a generic name ("New Folder") and immediately puts it in inline-rename mode (Windows 11 style).
    func createNewFolderInline(in pane: PaneViewModel) {
        activatePane(pane.side)
        pane.cancelInlineRename()
        do {
            let created = try service.createUniqueDirectory(baseName: "New Folder", in: pane.currentURL)
            if !pane.filterText.isEmpty {
                pane.filterText = ""
            }
            refreshAll()
            pane.clearSelection()
            pane.refresh(selectName: created.lastPathComponent)
            if let createdItem = pane.items.first(where: { $0.url.standardizedFileURL == created.standardizedFileURL }) {
                pane.beginInlineRename(for: createdItem)
            }
            showStatus("Created \"\(created.lastPathComponent)\" — type a new name and press Return")
        } catch {
            alertError = error.localizedDescription
        }
    }

    /// Creates a typed file from a FileTemplate (with format-specific content/permissions) and immediately selects it for inline renaming.
    func createNewFile(from template: FileTemplate, in pane: PaneViewModel) {
        activatePane(pane.side)
        pane.cancelInlineRename()
        do {
            let created = try service.createFile(from: template, in: pane.currentURL)
            if !pane.filterText.isEmpty {
                pane.filterText = ""
            }
            refreshAll()
            pane.clearSelection()
            pane.refresh(selectName: created.lastPathComponent)
            if let createdItem = pane.items.first(where: { $0.url.standardizedFileURL == created.standardizedFileURL }) {
                pane.beginInlineRename(for: createdItem)
            }
            let extraNote = template.isExecutable ? " (executable)" : ""
            showStatus("Created \(template.displayName)\(extraNote) — type a new name and press Return")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func beginInlineRename(in pane: PaneViewModel, item: FileItem? = nil) {
        activatePane(pane.side)
        let target = item ?? pane.cursorItem
        guard let target, !target.isParentEntry else {
            showStatus("Select a file or folder to rename")
            return
        }
        pane.beginInlineRename(for: target)
    }

    func commitInlineRename(in pane: PaneViewModel, item: FileItem, newName: String) {
        pane.renamingItemID = nil
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }
        do {
            let renamed = try service.renameItem(at: item.url, to: trimmed)
            refreshAll()
            pane.refresh(selectName: renamed.lastPathComponent)
            showStatus("Renamed to \"\(renamed.lastPathComponent)\"")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func copySelectionToClipboard(from pane: PaneViewModel) {
        activatePane(pane.side)
        let targets = pane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("No items selected to copy")
            return
        }
        let urls = targets.map(\.url)
        fileClipboard = FileClipboard(urls: urls, mode: .copy)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
        showStatus("Copied \(urls.count) item(s) to clipboard")
    }

    func cutSelectionToClipboard(from pane: PaneViewModel) {
        activatePane(pane.side)
        let targets = pane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("No items selected to cut")
            return
        }
        let urls = targets.map(\.url)
        fileClipboard = FileClipboard(urls: urls, mode: .cut)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects(urls as [NSURL])
        showStatus("Cut \(urls.count) item(s) — navigate to destination and click Paste")
    }

    func pasteFromClipboard(into pane: PaneViewModel) {
        activatePane(pane.side)
        let destURL = pane.currentURL

        let urlsToProcess: [URL]
        let isCut: Bool
        if let clip = fileClipboard, !clip.urls.isEmpty {
            urlsToProcess = clip.urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            isCut = (clip.mode == .cut)
        } else {
            urlsToProcess = systemPasteboardFileURLs()
            isCut = false
        }

        guard !urlsToProcess.isEmpty else {
            showStatus("Clipboard does not contain any files or folders")
            return
        }

        Task.detached { [weak self] in
            do {
                var lastName: String?
                if isCut {
                    try FileSystemService.shared.moveItems(urlsToProcess, to: destURL, overwrite: false)
                    lastName = urlsToProcess.last?.lastPathComponent
                } else {
                    let created = try FileSystemService.shared.pasteCopyItems(urlsToProcess, to: destURL)
                    lastName = created.last?.lastPathComponent
                }
                await MainActor.run {
                    if isCut {
                        self?.fileClipboard = nil
                    }
                    self?.leftPane.clearSelection()
                    self?.rightPane.clearSelection()
                    self?.refreshAll()
                    if let lastName {
                        pane.refresh(selectName: lastName)
                    }
                    let verb = isCut ? "Moved" : "Pasted"
                    self?.showStatus("\(verb) \(urlsToProcess.count) item(s) into \(destURL.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func triggerProperties(in pane: PaneViewModel, item: FileItem? = nil) {
        activatePane(pane.side)
        let target = item ?? pane.cursorItem
        guard let target, !target.isParentEntry else {
            showStatus("Select a file or folder to inspect properties")
            return
        }
        activeSheet = .properties(target)
    }

    func compressSelection(in pane: PaneViewModel) {
        activatePane(pane.side)
        let targets = pane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("Select one or more items to compress")
            return
        }
        let urls = targets.map(\.url)
        let directory = pane.currentURL
        showStatus("Compressing \(urls.count) item(s)...")

        Task.detached { [weak self] in
            do {
                let zipURL = try FileSystemService.shared.compressItems(urls, in: directory)
                await MainActor.run {
                    self?.refreshAll()
                    pane.refresh(selectName: zipURL.lastPathComponent)
                    self?.showStatus("Created archive \"\(zipURL.lastPathComponent)\"")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func extractSelectedZip(in pane: PaneViewModel) {
        activatePane(pane.side)
        guard let item = pane.cursorItem, !item.isParentEntry, !item.isDirectory, item.fileExtension.lowercased() == "zip" else {
            showStatus("Select a .zip archive to extract")
            return
        }
        let zipURL = item.url
        let dest = pane.currentURL
        showStatus("Extracting \"\(item.name)\"...")

        Task.detached { [weak self] in
            do {
                let extractedFolder = try FileSystemService.shared.extractZipArchive(at: zipURL, into: dest)
                await MainActor.run {
                    self?.refreshAll()
                    pane.refresh(selectName: extractedFolder.lastPathComponent)
                    self?.showStatus("Extracted into \"\(extractedFolder.lastPathComponent)\"")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func calculateSelectedFolderSize(in pane: PaneViewModel) {
        activatePane(pane.side)
        let folders = pane.effectiveSelectedItems.filter { $0.isDirectory && !$0.isParentEntry }
        guard !folders.isEmpty else {
            showStatus("Select a folder to calculate its total size")
            return
        }
        showStatus("Calculating size for \(folders.count) folder(s)...")

        Task.detached { [weak self] in
            var computed: [(String, Int64, Int, Int)] = []
            for folder in folders {
                let stats = FileSystemService.shared.calculateDirectoryStats(at: folder.url)
                computed.append((folder.id, stats.totalBytes, stats.fileCount, stats.folderCount))
            }
            await MainActor.run {
                for (id, bytes, _, _) in computed {
                    pane.calculatedFolderSizes[id] = bytes
                }
                if computed.count == 1, let first = computed.first {
                    let formatted = ByteCountFormatter.string(fromByteCount: first.1, countStyle: .file)
                    self?.showStatus("Folder size: \(formatted) (\(first.2) files, \(first.3) subfolders)")
                } else {
                    let grandTotal = computed.reduce(Int64(0)) { $0 + $1.1 }
                    let formatted = ByteCountFormatter.string(fromByteCount: grandTotal, countStyle: .file)
                    self?.showStatus("Calculated \(computed.count) folders: \(formatted) total")
                }
            }
        }
    }

    func triggerViewFile(in pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        guard let item = activePane.cursorItem, !item.isParentEntry, !item.isDirectory else {
            showStatus("Select a file to view (F3)")
            return
        }
        activeSheet = .viewer(item)
    }

    func triggerEditFile(in pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        guard let item = activePane.cursorItem, !item.isParentEntry, !item.isDirectory else {
            showStatus("Select a text file to edit (F4)")
            return
        }
        activeSheet = .editor(item)
    }

    func triggerCopy(from pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        let targets = activePane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("No items selected to copy")
            return
        }
        let destination = layoutMode == .dualPane ? inactivePane.currentURL : activePane.currentURL
        activeSheet = .copy(items: targets, destination: destination)
    }

    func triggerMove(from pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        let targets = activePane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("No items selected to move")
            return
        }
        let destination = layoutMode == .dualPane ? inactivePane.currentURL : activePane.currentURL
        activeSheet = .move(items: targets, destination: destination)
    }

    func triggerRename() {
        guard let item = activePane.cursorItem, !item.isParentEntry else {
            showStatus("Select an item to rename")
            return
        }
        activeSheet = .rename(item)
    }

    func triggerMakeDirectory() {
        activeSheet = .makeDirectory(parent: activePane.currentURL)
    }

    func triggerNewFile(in pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        activeSheet = .newFile(parent: activePane.currentURL)
    }

    func triggerDelete(in pane: PaneViewModel? = nil) {
        if let pane { activatePane(pane.side) }
        let targets = activePane.effectiveSelectedItems
        guard !targets.isEmpty else {
            showStatus("No items selected to delete")
            return
        }
        activeSheet = .delete(items: targets)
    }

    func triggerWildcardSelection(select: Bool) {
        activeSheet = .wildcard(select: select)
    }

    func triggerOpenTerminal() {
        service.openInTerminal(directory: activePane.currentURL)
        showStatus("Opened Terminal in \(activePane.currentURL.lastPathComponent)")
    }

    func triggerQuit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Execution of File Operations

    func performCopy(items: [FileItem], to destinationPath: String, overwrite: Bool) {
        let expanded = (destinationPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        let destURL = URL(fileURLWithPath: expanded)
        let urls = items.map(\.url)

        Task.detached { [weak self] in
            do {
                try FileSystemService.shared.copyItems(urls, to: destURL, overwrite: overwrite)
                await MainActor.run {
                    self?.leftPane.clearSelection()
                    self?.rightPane.clearSelection()
                    self?.refreshAll()
                    self?.showStatus("Copied \(urls.count) item(s) to \(destURL.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func performMove(items: [FileItem], to destinationPath: String, overwrite: Bool) {
        let expanded = (destinationPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        let destURL = URL(fileURLWithPath: expanded)
        let urls = items.map(\.url)

        Task.detached { [weak self] in
            do {
                try FileSystemService.shared.moveItems(urls, to: destURL, overwrite: overwrite)
                await MainActor.run {
                    self?.leftPane.clearSelection()
                    self?.rightPane.clearSelection()
                    self?.refreshAll()
                    self?.showStatus("Moved \(urls.count) item(s) to \(destURL.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func performRename(item: FileItem, newName: String) {
        do {
            let renamed = try service.renameItem(at: item.url, to: newName)
            refreshAll()
            activePane.refresh(selectName: renamed.lastPathComponent)
            showStatus("Renamed to \"\(renamed.lastPathComponent)\"")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func performCreateDirectory(name: String, in parentURL: URL) {
        do {
            let created = try service.createDirectory(named: name, in: parentURL)
            refreshAll()
            activePane.refresh(selectName: created.lastPathComponent)
            showStatus("Created folder \"\(created.lastPathComponent)\"")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func performCreateFile(name: String, in parentURL: URL) {
        do {
            let created = try service.createEmptyFile(named: name, in: parentURL)
            refreshAll()
            activePane.refresh(selectName: created.lastPathComponent)
            showStatus("Created file \"\(created.lastPathComponent)\"")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func performDuplicate(item: FileItem) {
        guard !item.isParentEntry else { return }
        do {
            let created = try service.duplicateItem(at: item.url)
            refreshAll()
            activePane.refresh(selectName: created.lastPathComponent)
            showStatus("Duplicated as \"\(created.lastPathComponent)\"")
        } catch {
            alertError = error.localizedDescription
        }
    }

    func performDelete(items: [FileItem], permanent: Bool) {
        let urls = items.map(\.url)
        Task.detached { [weak self] in
            do {
                if permanent {
                    try FileSystemService.shared.deletePermanently(urls)
                } else {
                    try FileSystemService.shared.trashItems(urls)
                }
                await MainActor.run {
                    self?.leftPane.clearSelection()
                    self?.rightPane.clearSelection()
                    self?.refreshAll()
                    let verb = permanent ? "Permanently deleted" : "Moved to Trash"
                    self?.showStatus("\(verb): \(urls.count) item(s)")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func handleFileDrop(urls: [URL], onto targetPane: PaneViewModel, move: Bool = false) {
        guard !urls.isEmpty else { return }
        let dest = targetPane.currentURL
        Task.detached { [weak self] in
            do {
                if move {
                    try FileSystemService.shared.moveItems(urls, to: dest, overwrite: false)
                } else {
                    try FileSystemService.shared.copyItems(urls, to: dest, overwrite: false)
                }
                await MainActor.run {
                    self?.refreshAll()
                    let verb = move ? "Moved" : "Copied"
                    self?.showStatus("\(verb) \(urls.count) dropped item(s) to \(dest.lastPathComponent)")
                }
            } catch {
                await MainActor.run {
                    self?.alertError = error.localizedDescription
                }
            }
        }
    }

    func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func copyPathToClipboard(_ item: FileItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.url.path, forType: .string)
        showStatus("Copied path: \(item.url.path)")
    }

    // MARK: - Integrated Command Line

    func executeCommandLine(_ rawCommand: String) {
        let trimmed = rawCommand.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Handle built-in `cd` directly to navigate the active pane (just like Norton Commander!).
        if trimmed == "cd" || trimmed == "cd ~" {
            activePane.navigate(to: FileManager.default.homeDirectoryForCurrentUser)
            showStatus("Changed directory to Home")
            return
        }
        if trimmed.hasPrefix("cd ") {
            let arg = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
            if arg == ".." {
                activePane.goUp()
            } else {
                activePane.navigateFromTypedPath(arg)
            }
            return
        }

        shellRunner.run(command: trimmed, in: activePane.currentURL) { [weak self] in
            self?.refreshAll()
        }
    }

    // MARK: - Status Banner

    func showStatus(_ message: String) {
        statusBanner = message
        bannerClearTask?.cancel()
        bannerClearTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            guard !Task.isCancelled else { return }
            self?.statusBanner = nil
        }
    }

    // MARK: - Global Keyboard Monitor

    private func setupKeyboardMonitor() {
        keyboardMonitor.start { [weak self] action in
            guard let self else { return false }
            Task { @MainActor in
                switch action {
                case .switchPane:
                    self.switchActivePane()
                case .moveUp:
                    self.activePane.moveCursor(by: -1)
                case .moveDown:
                    self.activePane.moveCursor(by: 1)
                case .moveHome:
                    self.activePane.moveCursorToStart()
                case .moveEnd:
                    self.activePane.moveCursorToEnd()
                case .pageUp:
                    self.activePane.moveCursor(by: -15)
                case .pageDown:
                    self.activePane.moveCursor(by: 15)
                case .openSelected:
                    self.activePane.openCursorItem()
                case .goParent:
                    self.activePane.goUp()
                case .toggleSelection:
                    self.activePane.toggleSelectionAtCursorAndAdvance()
                case .renameItem:
                    self.beginInlineRename(in: self.activePane)
                case .viewFile:
                    self.triggerViewFile()
                case .editFile:
                    self.triggerEditFile()
                case .copyItems:
                    self.triggerCopy()
                case .moveItems:
                    self.triggerMove()
                case .makeDirectory:
                    self.triggerMakeDirectory()
                case .deleteItems:
                    self.triggerDelete()
                case .openTerminal:
                    self.triggerOpenTerminal()
                case .quitApp:
                    self.triggerQuit()
                case .wildcardSelect:
                    self.triggerWildcardSelection(select: true)
                case .wildcardDeselect:
                    self.triggerWildcardSelection(select: false)
                }
            }
            return true
        }
    }
}
