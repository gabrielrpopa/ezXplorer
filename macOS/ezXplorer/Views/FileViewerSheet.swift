import SwiftUI
import AppKit

/// Built-in F3 File Viewer supporting plain text, images, and automatic hex dump for binary files.
struct FileViewerSheet: View {
    let item: FileItem
    @Environment(\.dismiss) private var dismiss

    @State private var content: String = ""
    @State private var isHexDump: Bool = false
    @State private var isTruncated: Bool = false
    @State private var loadedImage: NSImage?
    @State private var wrapLines: Bool = true
    @State private var searchQuery: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 20, height: 20)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.headline)
                    Text("\(item.url.path)  •  \(item.formattedSize)\(isHexDump ? "  •  Hex Mode" : "")\(isTruncated ? "  •  Truncated Preview" : "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()

                if loadedImage == nil {
                    Toggle("Wrap", isOn: $wrapLines)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                }

                Button("Open External") {
                    NSWorkspace.shared.open(item.url)
                }
                .controlSize(.small)

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .controlSize(.small)
            }
            .padding(12)
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            // Content body
            if let img = loadedImage {
                ScrollView([.horizontal, .vertical]) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 820, maxHeight: 540)
                        .padding(16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Filter lines containing...", text: $searchQuery)
                        .textFieldStyle(.plain)
                    if !searchQuery.isEmpty {
                        Button("Clear") { searchQuery = "" }
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))

                Divider()

                ScrollView(wrapLines ? [.vertical] : [.horizontal, .vertical]) {
                    Text(displayedText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .textSelection(.enabled)
                }
                .background(Color(nsColor: .textBackgroundColor))
            }
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            loadContent()
        }
    }

    private var displayedText: String {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return content }
        let matched = content
            .components(separatedBy: .newlines)
            .enumerated()
            .filter { $0.element.localizedCaseInsensitiveContains(query) }
            .map { String(format: "%5d | %@", $0.offset + 1, $0.element) }
        return matched.isEmpty ? "No lines matched \"\(query)\"." : matched.joined(separator: "\n")
    }

    private func loadContent() {
        if item.isImageFile, let img = NSImage(contentsOf: item.url) {
            loadedImage = img
            return
        }
        let result = FileSystemService.shared.loadFilePreview(at: item.url)
        content = result.content
        isHexDump = result.isHexDump
        isTruncated = result.isTruncated
    }
}
