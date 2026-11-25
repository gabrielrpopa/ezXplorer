import Foundation
import AppKit
import UniformTypeIdentifiers

enum FileSystemError: LocalizedError {
    case destinationExists(String)
    case unreadableDirectory(String)
    case invalidName(String)
    case operationFailed(String)

    var errorDescription: String? {
        switch self {
        case .destinationExists(let name):
            return "An item named \"\(name)\" already exists at the destination."
        case .unreadableDirectory(let path):
            return "Unable to read directory: \(path)"
        case .invalidName(let name):
            return "Invalid file or folder name: \"\(name)\""
        case .operationFailed(let detail):
            return detail
        }
    }
}

struct DirectoryListingResult {
    let items: [FileItem]
    let freeSpaceBytes: Int64?
    let totalFiles: Int
    let totalFolders: Int
    let totalBytes: Int64
}

struct DirectoryComparisonResult {
    let leftStatuses: [String: CompareStatus]
    let rightStatuses: [String: CompareStatus]
}

/// Core filesystem operations shared by both Commander (dual-pane) and Explorer workflows.
final class FileSystemService {
    static let shared = FileSystemService()
    private init() {}

    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isSymbolicLinkKey,
        .isHiddenKey,
        .isPackageKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey,
        .localizedTypeDescriptionKey
    ]

    func listDirectory(
        at url: URL,
        showHidden: Bool,
        sortField: SortField,
        ascending: Bool,
        includeParentEntry: Bool = true
    ) throws -> DirectoryListingResult {
        let fm = FileManager.default
        let standardized = url.standardizedFileURL

        let options: FileManager.DirectoryEnumerationOptions = showHidden ? [] : [.skipsHiddenFiles]
        let childURLs: [URL]
        do {
            childURLs = try fm.contentsOfDirectory(
                at: standardized,
                includingPropertiesForKeys: Array(resourceKeys),
                options: options
            )
        } catch {
            throw FileSystemError.unreadableDirectory(standardized.path)
        }

        var folders: [FileItem] = []
        var files: [FileItem] = []
        var totalBytes: Int64 = 0

        for childURL in childURLs {
            let values = try? childURL.resourceValues(forKeys: resourceKeys)
            let isPackage = values?.isPackage ?? false
            let isDir = (values?.isDirectory ?? false) && !isPackage
            let isSymlink = values?.isSymbolicLink ?? false
            let isHidden = values?.isHidden ?? childURL.lastPathComponent.hasPrefix(".")
            let fileSize: Int64? = isDir ? nil : values?.fileSize.map(Int64.init)
            let attrs = try? fm.attributesOfItem(atPath: childURL.path)
            let posix = attrs?[.posixPermissions] as? Int

            if let fileSize {
                totalBytes += fileSize
            }

            let item = FileItem(
                url: childURL,
                name: childURL.lastPathComponent,
                fileExtension: isDir ? "" : childURL.pathExtension,
                isDirectory: isDir,
                isSymbolicLink: isSymlink,
                isHidden: isHidden,
                isParentEntry: false,
                size: fileSize,
                modificationDate: values?.contentModificationDate,
                creationDate: values?.creationDate,
                contentTypeDescription: values?.localizedTypeDescription ?? (isDir ? "Folder" : "Document"),
                posixPermissions: posix
            )

            if isDir {
                folders.append(item)
            } else {
                files.append(item)
            }
        }

        let comparator: (FileItem, FileItem) -> Bool = { lhs, rhs in
            let order: ComparisonResult
            switch sortField {
            case .name:
                order = lhs.name.localizedStandardCompare(rhs.name)
            case .fileExtension:
                let extOrder = lhs.fileExtension.localizedStandardCompare(rhs.fileExtension)
                order = extOrder == .orderedSame ? lhs.name.localizedStandardCompare(rhs.name) : extOrder
            case .size:
                let lSize = lhs.size ?? -1
                let rSize = rhs.size ?? -1
                if lSize == rSize {
                    order = lhs.name.localizedStandardCompare(rhs.name)
                } else {
                    order = lSize < rSize ? .orderedAscending : .orderedDescending
                }
            case .date:
                let lDate = lhs.modificationDate ?? .distantPast
                let rDate = rhs.modificationDate ?? .distantPast
                if lDate == rDate {
                    order = lhs.name.localizedStandardCompare(rhs.name)
                } else {
                    order = lDate < rDate ? .orderedAscending : .orderedDescending
                }
            }
            return ascending ? (order == .orderedAscending) : (order == .orderedDescending)
        }

        folders.sort(by: comparator)
        files.sort(by: comparator)

        var combined: [FileItem] = []
        if includeParentEntry && standardized.path != "/" {
            combined.append(FileItem.parentEntry(for: standardized.deletingLastPathComponent()))
        }
        combined.append(contentsOf: folders)
        combined.append(contentsOf: files)

        let freeSpace = volumeAvailableSpace(at: standardized)
        return DirectoryListingResult(
            items: combined,
            freeSpaceBytes: freeSpace,
            totalFiles: files.count,
            totalFolders: folders.count,
            totalBytes: totalBytes
        )
    }

    func volumeAvailableSpace(at url: URL) -> Int64? {
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values?.volumeAvailableCapacityForImportantUsage {
            return important
        }
        if let regular = values?.volumeAvailableCapacity {
            return Int64(regular)
        }
        return nil
    }

    func copyItems(_ items: [URL], to destinationDirectory: URL, overwrite: Bool) throws {
        let fm = FileManager.default
        for source in items {
            let target = destinationDirectory.appendingPathComponent(source.lastPathComponent)
            if source.standardizedFileURL == target.standardizedFileURL {
                let uniqueTarget = uniqueURL(for: target)
                try fm.copyItem(at: source, to: uniqueTarget)
                continue
            }
            if fm.fileExists(atPath: target.path) {
                if overwrite {
                    try fm.removeItem(at: target)
                } else {
                    throw FileSystemError.destinationExists(source.lastPathComponent)
                }
            }
            try fm.copyItem(at: source, to: target)
        }
    }

    func moveItems(_ items: [URL], to destinationDirectory: URL, overwrite: Bool) throws {
        let fm = FileManager.default
        for source in items {
            let target = destinationDirectory.appendingPathComponent(source.lastPathComponent)
            if source.standardizedFileURL == target.standardizedFileURL {
                continue
            }
            if fm.fileExists(atPath: target.path) {
                if overwrite {
                    try fm.removeItem(at: target)
                } else {
                    throw FileSystemError.destinationExists(source.lastPathComponent)
                }
            }
            try fm.moveItem(at: source, to: target)
        }
    }

    func renameItem(at source: URL, to newName: String) throws -> URL {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(":") else {
            throw FileSystemError.invalidName(newName)
        }
        let target = source.deletingLastPathComponent().appendingPathComponent(trimmed)
        if source.standardizedFileURL == target.standardizedFileURL {
            return target
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path) {
            throw FileSystemError.destinationExists(trimmed)
        }
        try fm.moveItem(at: source, to: target)
        return target
    }

    func createDirectory(named name: String, in parentDirectory: URL) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(":") else {
            throw FileSystemError.invalidName(name)
        }
        let target = parentDirectory.appendingPathComponent(trimmed)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        return target
    }

    /// Creates a new folder with a collision-free generic name (e.g. "New Folder", "New Folder (2)"),
    /// matching Windows 11 File Explorer behavior.
    func createUniqueDirectory(baseName: String = "New Folder", in parentDirectory: URL) throws -> URL {
        let target = uniqueNumberedURL(baseName: baseName, fileExtension: nil, in: parentDirectory)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: false)
        return target
    }

    func createEmptyFile(named name: String, in parentDirectory: URL) throws -> URL {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("/"), !trimmed.contains(":") else {
            throw FileSystemError.invalidName(name)
        }
        let target = parentDirectory.appendingPathComponent(trimmed)
        let fm = FileManager.default
        if fm.fileExists(atPath: target.path) {
            throw FileSystemError.destinationExists(trimmed)
        }
        guard fm.createFile(atPath: target.path, contents: Data()) else {
            throw FileSystemError.operationFailed("Could not create file \(trimmed).")
        }
        return target
    }

    /// Creates a new file from a typed template with collision-free generic naming, starter bytes,
    /// and executable permissions when appropriate (e.g. `.sh` scripts).
    func createFile(from template: FileTemplate, in parentDirectory: URL) throws -> URL {
        let target = uniqueNumberedURL(
            baseName: template.defaultBaseName,
            fileExtension: template.fileExtension,
            in: parentDirectory
        )
        let fm = FileManager.default
        let attributes: [FileAttributeKey: Any]? = template.isExecutable
            ? [.posixPermissions: 0o755]
            : nil
        guard fm.createFile(atPath: target.path, contents: template.initialData, attributes: attributes) else {
            throw FileSystemError.operationFailed("Could not create \(target.lastPathComponent).")
        }
        return target
    }

    func uniqueNumberedURL(baseName: String, fileExtension: String?, in parentDirectory: URL) -> URL {
        let fm = FileManager.default
        let cleanExt = (fileExtension ?? "").trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let firstName = cleanExt.isEmpty ? baseName : "\(baseName).\(cleanExt)"
        let firstCandidate = parentDirectory.appendingPathComponent(firstName)
        if !fm.fileExists(atPath: firstCandidate.path) {
            return firstCandidate
        }
        var counter = 2
        while true {
            let numbered = cleanExt.isEmpty ? "\(baseName) (\(counter))" : "\(baseName) (\(counter)).\(cleanExt)"
            let candidate = parentDirectory.appendingPathComponent(numbered)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    /// Copies items into destinationDirectory, automatically assigning unique names on conflict (Explorer Paste style).
    func pasteCopyItems(_ items: [URL], to destinationDirectory: URL) throws -> [URL] {
        let fm = FileManager.default
        var created: [URL] = []
        for source in items {
            let desired = destinationDirectory.appendingPathComponent(source.lastPathComponent)
            let target = fm.fileExists(atPath: desired.path) ? uniqueURL(for: desired) : desired
            try fm.copyItem(at: source, to: target)
            created.append(target)
        }
        return created
    }

    /// Compresses one or more items into a `.zip` archive in `directory` (Windows 11 Compress / NC Alt+F5).
    func compressItems(_ items: [URL], in directory: URL) throws -> URL {
        guard !items.isEmpty else {
            throw FileSystemError.operationFailed("No items selected to compress.")
        }
        let baseName: String
        if items.count == 1, let first = items.first {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir)
            baseName = isDir.boolValue ? first.lastPathComponent : first.deletingPathExtension().lastPathComponent
        } else {
            baseName = "Archive"
        }

        let zipURL = uniqueNumberedURL(baseName: baseName.isEmpty ? "Archive" : baseName, fileExtension: "zip", in: directory)
        let relativeNames = items.map(\.lastPathComponent)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-r", "-y", "-q", zipURL.path] + relativeNames

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Compression failed."
            throw FileSystemError.operationFailed(errText.isEmpty ? "Compression failed (exit \(process.terminationStatus))." : errText)
        }
        return zipURL
    }

    /// Extracts a `.zip` archive into a new folder alongside it (Windows 11 Extract / NC Unpack).
    func extractZipArchive(at zipURL: URL, into destinationDirectory: URL) throws -> URL {
        let baseName = zipURL.deletingPathExtension().lastPathComponent
        let targetDir = uniqueNumberedURL(baseName: baseName.isEmpty ? "Extracted" : baseName, fileExtension: nil, in: destinationDirectory)
        try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-x", "-k", zipURL.path, targetDir.path]

        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Extraction failed."
            throw FileSystemError.operationFailed(errText.isEmpty ? "Extraction failed (exit \(process.terminationStatus))." : errText)
        }
        return targetDir
    }

    /// Recursively computes total byte size and item counts for a directory (Explorer Properties / NC Folder Size).
    func calculateDirectoryStats(at url: URL) -> (totalBytes: Int64, fileCount: Int, folderCount: Int) {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey, .fileSizeKey]
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return (0, 0, 0)
        }

        var totalBytes: Int64 = 0
        var fileCount = 0
        var folderCount = 0

        for case let childURL as URL in enumerator {
            guard let values = try? childURL.resourceValues(forKeys: Set(keys)) else { continue }
            let isDir = (values.isDirectory ?? false) && !(values.isPackage ?? false)
            if isDir {
                folderCount += 1
            } else {
                fileCount += 1
                totalBytes += Int64(values.fileSize ?? 0)
            }
        }
        return (totalBytes, fileCount, folderCount)
    }

    func duplicateItem(at source: URL) throws -> URL {
        let target = uniqueURL(for: source)
        try FileManager.default.copyItem(at: source, to: target)
        return target
    }

    func trashItems(_ items: [URL]) throws {
        let fm = FileManager.default
        for url in items {
            var resultingURL: NSURL?
            try fm.trashItem(at: url, resultingItemURL: &resultingURL)
        }
    }

    func deletePermanently(_ items: [URL]) throws {
        let fm = FileManager.default
        for url in items {
            try fm.removeItem(at: url)
        }
    }

    func uniqueURL(for desiredURL: URL) -> URL {
        let fm = FileManager.default
        if !fm.fileExists(atPath: desiredURL.path) {
            return desiredURL
        }
        let dir = desiredURL.deletingLastPathComponent()
        let ext = desiredURL.pathExtension
        let base = desiredURL.deletingPathExtension().lastPathComponent
        var counter = 1
        while true {
            let suffix = counter == 1 ? " copy" : " copy \(counter)"
            let candidateName = ext.isEmpty ? "\(base)\(suffix)" : "\(base)\(suffix).\(ext)"
            let candidate = dir.appendingPathComponent(candidateName)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            counter += 1
        }
    }

    /// Compares two directory listings (classic Norton Commander F9 -> Compare Directories).
    func compareDirectories(leftItems: [FileItem], rightItems: [FileItem]) -> DirectoryComparisonResult {
        let leftMap = Dictionary(uniqueKeysWithValues: leftItems.filter { !$0.isParentEntry }.map { ($0.name, $0) })
        let rightMap = Dictionary(uniqueKeysWithValues: rightItems.filter { !$0.isParentEntry }.map { ($0.name, $0) })

        var leftStatuses: [String: CompareStatus] = [:]
        var rightStatuses: [String: CompareStatus] = [:]

        for (name, lItem) in leftMap {
            guard let rItem = rightMap[name] else {
                leftStatuses[lItem.id] = .unique
                continue
            }
            if let lDate = lItem.modificationDate, let rDate = rItem.modificationDate, lDate.timeIntervalSince(rDate) > 1.0 {
                leftStatuses[lItem.id] = .newer
            }
        }

        for (name, rItem) in rightMap {
            guard let lItem = leftMap[name] else {
                rightStatuses[rItem.id] = .unique
                continue
            }
            if let rDate = rItem.modificationDate, let lDate = lItem.modificationDate, rDate.timeIntervalSince(lDate) > 1.0 {
                rightStatuses[rItem.id] = .newer
            }
        }

        return DirectoryComparisonResult(leftStatuses: leftStatuses, rightStatuses: rightStatuses)
    }

    /// Glob/wildcard matching (`*` and `?`) for Norton Commander `+` / `-` batch selection.
    func matchesWildcard(name: String, pattern: String) -> Bool {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: trimmed)
            .replacingOccurrences(of: "\\*", with: ".*")
            .replacingOccurrences(of: "\\?", with: ".")
        let regexPattern = "^\(escaped)$"
        return name.range(of: regexPattern, options: [.regularExpression, .caseInsensitive]) != nil
    }

    /// Reads text or falls back to formatted hex dump for the F3 built-in viewer.
    func loadFilePreview(at url: URL, maxBytes: Int = 512_000) -> (content: String, isHexDump: Bool, isTruncated: Bool) {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return ("Unable to open file for reading.", false, false)
        }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: maxBytes + 1)) ?? Data()
        let isTruncated = data.count > maxBytes
        let slice = isTruncated ? data.prefix(maxBytes) : data

        // Heuristic: treat as binary if it contains NUL bytes in the first 4KB.
        let sample = slice.prefix(4096)
        let hasNullByte = sample.contains(0)
        if !hasNullByte, let text = String(data: slice, encoding: .utf8) ?? String(data: slice, encoding: .isoLatin1) {
            return (text, false, isTruncated)
        }

        return (formatHexDump(data: slice.prefix(32_768)), true, slice.count > 32_768 || isTruncated)
    }

    private func formatHexDump(data: Data) -> String {
        var lines: [String] = []
        let bytesPerRow = 16
        var offset = 0
        while offset < data.count {
            let end = min(offset + bytesPerRow, data.count)
            let chunk = data[offset..<end]
            let hexPart = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let paddedHex = hexPart.padding(toLength: bytesPerRow * 3 - 1, withPad: " ", startingAt: 0)
            let asciiPart = chunk.map { byte -> String in
                (byte >= 32 && byte <= 126) ? String(UnicodeScalar(byte)) : "."
            }.joined()
            lines.append(String(format: "%08X  %@  |%@|", offset, paddedHex, asciiPart))
            offset += bytesPerRow
        }
        return lines.isEmpty ? "(Empty file)" : lines.joined(separator: "\n")
    }

    /// Returns standard macOS Quick Access locations (Windows Explorer sidebar style).
    func quickAccessLocations() -> [QuickAccessLocation] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser
        var results: [QuickAccessLocation] = [
            QuickAccessLocation(title: "Home", url: home, systemImage: "house.fill")
        ]

        let standardDirs: [(String, FileManager.SearchPathDirectory, String)] = [
            ("Desktop", .desktopDirectory, "menubar.dock.rectangle"),
            ("Documents", .documentDirectory, "doc.text.fill"),
            ("Downloads", .downloadsDirectory, "arrow.down.circle.fill"),
            ("Applications", .applicationDirectory, "square.grid.2x2.fill")
        ]

        for (title, searchDir, icon) in standardDirs {
            if let dirURL = fm.urls(for: searchDir, in: .userDomainMask).first, fm.fileExists(atPath: dirURL.path) {
                results.append(QuickAccessLocation(title: title, url: dirURL, systemImage: icon))
            } else if title == "Applications" {
                let sysApps = URL(fileURLWithPath: "/Applications")
                if fm.fileExists(atPath: sysApps.path) {
                    results.append(QuickAccessLocation(title: title, url: sysApps, systemImage: icon))
                }
            }
        }

        results.append(QuickAccessLocation(title: "Root (/)", url: URL(fileURLWithPath: "/"), systemImage: "internaldrive.fill"))
        return results
    }

    /// Lists mounted macOS volumes (like "This PC / Drives" in Explorer & Alt+F1/F2 drive selector in NC).
    func mountedVolumes() -> [QuickAccessLocation] {
        let keys: [URLResourceKey] = [.volumeNameKey, .volumeIsRemovableKey, .volumeIsInternalKey]
        guard let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: [.skipHiddenVolumes]) else {
            return []
        }
        return urls.map { url in
            let values = try? url.resourceValues(forKeys: Set(keys))
            let name = values?.volumeName ?? url.lastPathComponent
            let isRemovable = values?.volumeIsRemovable ?? false
            let icon = isRemovable ? "externaldrive.fill" : "internaldrive.fill"
            return QuickAccessLocation(title: name, url: url, systemImage: icon)
        }
    }

    /// Launches macOS Terminal.app at the specified directory.
    func openInTerminal(directory: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", directory.path]
        try? process.run()
    }
}
