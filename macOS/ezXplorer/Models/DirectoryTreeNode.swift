import Foundation

/// Lazy-loaded directory node used by the Windows Explorer–style sidebar folder tree.
@MainActor
final class DirectoryTreeNode: ObservableObject, Identifiable {
    let id: String
    let url: URL
    let name: String
    let systemImage: String

    @Published var children: [DirectoryTreeNode] = []
    @Published var isExpanded: Bool = false
    @Published var hasLoadedChildren: Bool = false

    init(url: URL, name: String? = nil, systemImage: String = "folder.fill") {
        self.id = url.path
        self.url = url
        self.name = name ?? (url.path == "/" ? "Macintosh HD" : url.lastPathComponent)
        self.systemImage = systemImage
    }

    func toggleExpanded(showHidden: Bool) {
        if !isExpanded && !hasLoadedChildren {
            loadChildren(showHidden: showHidden)
        }
        isExpanded.toggle()
    }

    func loadChildren(showHidden: Bool) {
        let fm = FileManager.default
        let options: FileManager.DirectoryEnumerationOptions = showHidden
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let urls = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey],
            options: options
        ) else {
            children = []
            hasLoadedChildren = true
            return
        }

        let dirs = urls.filter { childURL in
            let values = try? childURL.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return (values?.isDirectory ?? false) && !(values?.isPackage ?? false)
        }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        children = dirs.map { DirectoryTreeNode(url: $0) }
        hasLoadedChildren = true
    }
}

struct QuickAccessLocation: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let systemImage: String

    init(title: String, url: URL, systemImage: String) {
        self.id = "\(title)::\(url.path)"
        self.title = title
        self.url = url
        self.systemImage = systemImage
    }
}
