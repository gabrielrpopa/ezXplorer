import SwiftUI
import AppKit

/// Windows 11 Properties / macOS Get Info modal sheet with live recursive folder size calculation,
/// POSIX permissions, timestamps, symlink target, and quick Explorer/Commander actions.
struct PropertiesSheet: View {
    let item: FileItem
    let onCopyPath: () -> Void
    let onRevealInFinder: () -> Void
    let onOpenTerminal: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var folderStats: (totalBytes: Int64, fileCount: Int, folderCount: Int)?
    @State private var isCalculatingFolderSize: Bool = false
    @State private var symlinkTarget: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: item.icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.headline)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    Text(item.contentTypeDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    label("Location")
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                }

                GridRow {
                    label("Full Path")
                    Text(item.url.path)
                        .font(.system(size: 11.5, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                }

                GridRow {
                    label("Size")
                    sizeView
                }

                if let created = item.creationDate {
                    GridRow {
                        label("Created")
                        Text(Self.fullDateFormatter.string(from: created))
                            .font(.system(size: 12))
                    }
                }

                if let modified = item.modificationDate {
                    GridRow {
                        label("Modified")
                        Text(Self.fullDateFormatter.string(from: modified))
                            .font(.system(size: 12))
                    }
                }

                GridRow {
                    label("Permissions")
                    Text(permissionsSummary)
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }

                if let symlinkTarget {
                    GridRow {
                        label("Symlink Target")
                        Text(symlinkTarget)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    onCopyPath()
                } label: {
                    Label("Copy Path", systemImage: "link")
                }

                Button {
                    onRevealInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "macwindow")
                }

                Button {
                    onOpenTerminal()
                } label: {
                    Label("Terminal", systemImage: "terminal")
                }

                Spacer()

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(width: 500)
        .task {
            if item.isSymbolicLink {
                symlinkTarget = try? FileManager.default.destinationOfSymbolicLink(atPath: item.url.path)
            }
            if item.isDirectory {
                isCalculatingFolderSize = true
                let targetURL = item.url
                let computed = await Task.detached {
                    FileSystemService.shared.calculateDirectoryStats(at: targetURL)
                }.value
                folderStats = computed
                isCalculatingFolderSize = false
            }
        }
    }

    @ViewBuilder
    private var sizeView: some View {
        if item.isDirectory {
            if isCalculatingFolderSize {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Calculating folder size...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else if let stats = folderStats {
                let formatted = ByteCountFormatter.string(fromByteCount: stats.totalBytes, countStyle: .file)
                let exact = NumberFormatter.localizedString(from: NSNumber(value: stats.totalBytes), number: .decimal)
                Text("\(formatted) (\(exact) bytes) — \(stats.fileCount) files, \(stats.folderCount) subfolders")
                    .font(.system(size: 12))
                    .textSelection(.enabled)
            } else {
                Text("—")
                    .font(.system(size: 12))
            }
        } else if let bytes = item.size {
            let formatted = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            let exact = NumberFormatter.localizedString(from: NSNumber(value: bytes), number: .decimal)
            Text("\(formatted) (\(exact) bytes)")
                .font(.system(size: 12))
                .textSelection(.enabled)
        } else {
            Text("—")
                .font(.system(size: 12))
        }
    }

    private var permissionsSummary: String {
        if let perms = item.posixPermissions {
            return "\(item.formattedPermissions)  (\(String(format: "%04o", perms & 0o7777)))"
        }
        return item.formattedPermissions
    }

    private func label(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 96, alignment: .trailing)
    }

    private static let fullDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        return df
    }()
}
