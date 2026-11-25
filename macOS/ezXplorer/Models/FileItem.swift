import Foundation
import AppKit

/// Represents a single file, folder, symlink, or synthetic parent ("..") entry displayed in a pane.
struct FileItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let fileExtension: String
    let isDirectory: Bool
    let isSymbolicLink: Bool
    let isHidden: Bool
    let isParentEntry: Bool
    let size: Int64?
    let modificationDate: Date?
    let creationDate: Date?
    let contentTypeDescription: String
    let posixPermissions: Int?

    init(
        url: URL,
        name: String,
        fileExtension: String,
        isDirectory: Bool,
        isSymbolicLink: Bool = false,
        isHidden: Bool = false,
        isParentEntry: Bool = false,
        size: Int64? = nil,
        modificationDate: Date? = nil,
        creationDate: Date? = nil,
        contentTypeDescription: String = "",
        posixPermissions: Int? = nil
    ) {
        self.id = isParentEntry ? "__PARENT__::\(url.path)" : url.path
        self.url = url
        self.name = name
        self.fileExtension = fileExtension
        self.isDirectory = isDirectory
        self.isSymbolicLink = isSymbolicLink
        self.isHidden = isHidden
        self.isParentEntry = isParentEntry
        self.size = size
        self.modificationDate = modificationDate
        self.creationDate = creationDate
        self.contentTypeDescription = contentTypeDescription
        self.posixPermissions = posixPermissions
    }

    /// Creates the classic Norton Commander ".." entry pointing to the parent directory.
    static func parentEntry(for parentURL: URL) -> FileItem {
        FileItem(
            url: parentURL,
            name: "..",
            fileExtension: "",
            isDirectory: true,
            isParentEntry: true,
            contentTypeDescription: "Parent Folder"
        )
    }

    /// Native macOS icon for the file or directory.
    var icon: NSImage {
        if isParentEntry {
            return NSImage(systemSymbolName: "arrow.turn.left.up", accessibilityDescription: "Parent Folder")
                ?? NSWorkspace.shared.icon(forFile: url.path)
        }
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    var formattedSize: String {
        if isParentEntry { return "<UP-DIR>" }
        if isDirectory { return "<DIR>" }
        guard let size else { return "—" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        guard let modificationDate else { return "" }
        return FileItem.dateFormatter.string(from: modificationDate)
    }

    var formattedPermissions: String {
        guard let perms = posixPermissions else { return "---------" }
        let flags: [(Int, String)] = [
            (0o400, "r"), (0o200, "w"), (0o100, "x"),
            (0o040, "r"), (0o020, "w"), (0o010, "x"),
            (0o004, "r"), (0o002, "w"), (0o001, "x")
        ]
        return flags.map { (perms & $0.0) != 0 ? $0.1 : "-" }.joined()
    }

    var isImageFile: Bool {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "tif", "bmp", "webp", "svg", "icns"]
        return !isDirectory && imageExts.contains(fileExtension.lowercased())
    }

    var isLikelyTextFile: Bool {
        let textExts: Set<String> = [
            "txt", "md", "markdown", "swift", "h", "m", "mm", "c", "cpp", "hpp",
            "json", "xml", "yaml", "yml", "toml", "plist", "csv", "tsv", "sql",
            "sh", "zsh", "bash", "py", "rb", "js", "ts", "tsx", "jsx", "html",
            "css", "scss", "java", "kt", "go", "rs", "php", "log", "env",
            "gitignore", "dockerfile", "makefile", "ini", "conf", "cfg"
        ]
        if isDirectory { return false }
        if textExts.contains(fileExtension.lowercased()) { return true }
        let lowerName = name.lowercased()
        return ["readme", "license", "makefile", "dockerfile", "podfile", "gemfile"].contains(lowerName)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        return df
    }()
}
