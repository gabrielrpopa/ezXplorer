import SwiftUI
import AppKit

/// Windows Explorer–style right-hand preview & metadata inspector for the focused item.
struct PreviewInspectorView: View {
    let item: FileItem?
    let onViewFull: () -> Void
    let onEdit: () -> Void

    @State private var previewText: String = ""
    @State private var previewImage: NSImage?
    @State private var loadedItemID: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item, !item.isParentEntry {
                VStack(spacing: 8) {
                    if let img = previewImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 64, height: 64)
                    }

                    Text(item.name)
                        .font(.system(size: 13, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)

                    Text(item.contentTypeDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    metaRow("Size", item.formattedSize)
                    metaRow("Modified", item.formattedDate.isEmpty ? "—" : item.formattedDate)
                    metaRow("Permissions", item.formattedPermissions)
                    metaRow("Path", item.url.path)
                }
                .font(.system(size: 11))

                if !item.isDirectory {
                    HStack(spacing: 8) {
                        Button("View (F3)", action: onViewFull)
                            .controlSize(.small)
                        Button("Edit (F4)", action: onEdit)
                            .controlSize(.small)
                    }
                }

                if !previewText.isEmpty {
                    Divider()
                    Text("PREVIEW")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    ScrollView {
                        Text(previewText)
                            .font(.system(size: 10.5, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .padding(6)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                Spacer(minLength: 0)
            } else {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Select a file or folder to inspect")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding(12)
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: item?.id) { _, _ in
            loadPreviewIfNeeded()
        }
        .onAppear {
            loadPreviewIfNeeded()
        }
    }

    private func metaRow(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11, design: label == "Permissions" ? .monospaced : .default))
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    private func loadPreviewIfNeeded() {
        guard let item, !item.isParentEntry, !item.isDirectory else {
            previewImage = nil
            previewText = ""
            loadedItemID = ""
            return
        }
        guard loadedItemID != item.id else { return }
        loadedItemID = item.id

        if item.isImageFile {
            previewImage = NSImage(contentsOf: item.url)
            previewText = ""
        } else if item.isLikelyTextFile {
            previewImage = nil
            let result = FileSystemService.shared.loadFilePreview(at: item.url, maxBytes: 8_192)
            previewText = result.isHexDump ? "" : result.content
        } else {
            previewImage = nil
            previewText = ""
        }
    }
}
