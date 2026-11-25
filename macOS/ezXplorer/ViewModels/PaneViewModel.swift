import Foundation
import AppKit

/// Manages state, navigation history, selection, sorting, and cursor movement for a single file pane.
@MainActor
final class PaneViewModel: ObservableObject {
    let side: PaneSide

    @Published var currentURL: URL
    @Published var items: [FileItem] = []
    @Published var filterText: String = ""
    @Published var cursorID: String?
    @Published var selectedIDs: Set<String> = []
    @Published var compareStatuses: [String: CompareStatus] = [:]

    @Published var sortField: SortField = .name
    @Published var sortAscending: Bool = true
    @Published var showHidden: Bool = false

    @Published var historyBack: [URL] = []
    @Published var historyForward: [URL] = []

    @Published var freeSpaceBytes: Int64?
    @Published var totalFiles: Int = 0
    @Published var totalFolders: Int = 0
    @Published var totalBytes: Int64 = 0
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var isEditingPath: Bool = false
    @Published var renamingItemID: String?
    @Published var calculatedFolderSizes: [String: Int64] = [:]

    private let service = FileSystemService.shared

    init(side: PaneSide, initialURL: URL) {
        self.side = side
        self.currentURL = initialURL.standardizedFileURL
        refresh()
    }

    var filteredItems: [FileItem] {
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        return items.filter { item in
            item.isParentEntry || item.name.localizedCaseInsensitiveContains(query)
        }
    }

    var cursorItem: FileItem? {
        guard let cursorID else { return filteredItems.first }
        return filteredItems.first(where: { $0.id == cursorID }) ?? filteredItems.first
    }

    /// Norton Commander rule: operations act on marked items if any exist, otherwise on the item under the cursor.
    var effectiveSelectedItems: [FileItem] {
        let marked = items.filter { selectedIDs.contains($0.id) && !$0.isParentEntry }
        if !marked.isEmpty {
            return marked
        }
        if let current = cursorItem, !current.isParentEntry {
            return [current]
        }
        return []
    }

    var hasActionableSelection: Bool {
        !effectiveSelectedItems.isEmpty
    }

    var cursorIsFile: Bool {
        guard let item = cursorItem else { return false }
        return !item.isParentEntry && !item.isDirectory
    }

    var cursorIsFolder: Bool {
        guard let item = cursorItem else { return false }
        return !item.isParentEntry && item.isDirectory
    }

    var cursorIsZipArchive: Bool {
        guard let item = cursorItem else { return false }
        return !item.isParentEntry && !item.isDirectory && item.fileExtension.lowercased() == "zip"
    }

    func beginInlineRename(for item: FileItem? = nil) {
        let target = item ?? cursorItem
        guard let target, !target.isParentEntry else { return }
        cursorID = target.id
        renamingItemID = target.id
    }

    func cancelInlineRename() {
        renamingItemID = nil
    }

    var selectedBytes: Int64 {
        items.filter { selectedIDs.contains($0.id) && !$0.isParentEntry }
            .compactMap(\.size)
            .reduce(0, +)
    }

    var canGoBack: Bool { !historyBack.isEmpty }
    var canGoForward: Bool { !historyForward.isEmpty }
    var canGoUp: Bool { currentURL.path != "/" }

    var pathComponents: [(title: String, url: URL)] {
        let std = currentURL.standardizedFileURL
        let rawComponents = std.pathComponents
        var result: [(String, URL)] = []
        var runningURL = URL(fileURLWithPath: "/")

        for (index, comp) in rawComponents.enumerated() {
            if index == 0 && comp == "/" {
                result.append(("/", runningURL))
            } else {
                runningURL = runningURL.appendingPathComponent(comp)
                result.append((comp, runningURL))
            }
        }
        return result
    }

    func navigate(to url: URL, recordHistory: Bool = true, highlightChildNamed: String? = nil) {
        let target = url.standardizedFileURL
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDir), isDir.boolValue else {
            errorMessage = "Folder does not exist: \(target.path)"
            return
        }

        if recordHistory && target != currentURL {
            historyBack.append(currentURL)
            historyForward.removeAll()
        }

        currentURL = target
        filterText = ""
        selectedIDs.removeAll()
        compareStatuses.removeAll()
        renamingItemID = nil
        calculatedFolderSizes.removeAll()
        refresh(selectName: highlightChildNamed)
    }

    func navigateFromTypedPath(_ rawPath: String) {
        let expanded = (rawPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        guard !expanded.isEmpty else { return }
        let url: URL
        if expanded.hasPrefix("/") {
            url = URL(fileURLWithPath: expanded)
        } else {
            url = currentURL.appendingPathComponent(expanded)
        }
        navigate(to: url)
    }

    func goUp() {
        guard canGoUp else { return }
        let previousName = currentURL.lastPathComponent
        let parent = currentURL.deletingLastPathComponent()
        navigate(to: parent, recordHistory: true, highlightChildNamed: previousName)
    }

    func goBack() {
        guard let previous = historyBack.popLast() else { return }
        historyForward.append(currentURL)
        navigate(to: previous, recordHistory: false)
    }

    func goForward() {
        guard let next = historyForward.popLast() else { return }
        historyBack.append(currentURL)
        navigate(to: next, recordHistory: false)
    }

    func refresh(selectName: String? = nil) {
        isLoading = true
        errorMessage = nil
        let targetURL = currentURL
        let previousCursor = cursorID

        do {
            let listing = try service.listDirectory(
                at: targetURL,
                showHidden: showHidden,
                sortField: sortField,
                ascending: sortAscending,
                includeParentEntry: true
            )
            items = listing.items
            freeSpaceBytes = listing.freeSpaceBytes
            totalFiles = listing.totalFiles
            totalFolders = listing.totalFolders
            totalBytes = listing.totalBytes

            // Retain valid selection IDs.
            let validIDs = Set(items.map(\.id))
            selectedIDs = selectedIDs.intersection(validIDs)

            // Restore cursor position cleanly.
            if let selectName, let match = items.first(where: { $0.name == selectName }) {
                cursorID = match.id
            } else if let previousCursor, validIDs.contains(previousCursor) {
                cursorID = previousCursor
            } else {
                cursorID = items.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
            items = targetURL.path != "/" ? [FileItem.parentEntry(for: targetURL.deletingLastPathComponent())] : []
            cursorID = items.first?.id
        }

        isLoading = false
    }

    func setSort(field: SortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
        refresh()
    }

    func openItem(_ item: FileItem) {
        if item.isParentEntry {
            goUp()
        } else if item.isDirectory {
            navigate(to: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    func openCursorItem() {
        guard let item = cursorItem else { return }
        openItem(item)
    }

    func moveCursor(by delta: Int) {
        let list = filteredItems
        guard !list.isEmpty else { return }
        let currentIndex = list.firstIndex(where: { $0.id == cursorID }) ?? 0
        let nextIndex = max(0, min(list.count - 1, currentIndex + delta))
        cursorID = list[nextIndex].id
    }

    func moveCursorToStart() {
        cursorID = filteredItems.first?.id
    }

    func moveCursorToEnd() {
        cursorID = filteredItems.last?.id
    }

    /// Toggles selection on the cursor item and advances down one row (classic Norton Commander Space/Insert behavior).
    func toggleSelectionAtCursorAndAdvance() {
        guard let item = cursorItem else { return }
        if !item.isParentEntry {
            if selectedIDs.contains(item.id) {
                selectedIDs.remove(item.id)
            } else {
                selectedIDs.insert(item.id)
            }
        }
        moveCursor(by: 1)
    }

    func toggleSelection(for item: FileItem) {
        guard !item.isParentEntry else { return }
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
        cursorID = item.id
    }

    func selectSingle(_ item: FileItem) {
        cursorID = item.id
    }

    func selectAll() {
        selectedIDs = Set(filteredItems.filter { !$0.isParentEntry }.map(\.id))
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func invertSelection() {
        let allSelectable = Set(filteredItems.filter { !$0.isParentEntry }.map(\.id))
        selectedIDs = allSelectable.subtracting(selectedIDs)
    }

    func applyWildcard(pattern: String, select: Bool) {
        for item in filteredItems where !item.isParentEntry {
            if service.matchesWildcard(name: item.name, pattern: pattern) {
                if select {
                    selectedIDs.insert(item.id)
                } else {
                    selectedIDs.remove(item.id)
                }
            }
        }
    }
}
