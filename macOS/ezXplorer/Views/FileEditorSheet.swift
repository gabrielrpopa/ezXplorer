import SwiftUI
import AppKit

/// Built-in F4 Text Editor for quick in-place file edits without leaving the file manager.
struct FileEditorSheet: View {
    let item: FileItem
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @State private var originalText: String = ""
    @State private var loadError: String?
    @State private var saveError: String?

    private var hasUnsavedChanges: Bool {
        text != originalText
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: item.icon)
                    .resizable()
                    .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text(item.name)
                            .font(.headline)
                        if hasUnsavedChanges {
                            Text("Edited")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.orange.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }
                    Text(item.url.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                Spacer()

                if hasUnsavedChanges {
                    Button("Revert") {
                        text = originalText
                    }
                    .controlSize(.small)
                }

                Button("Save") {
                    saveFile()
                }
                .keyboardShortcut("s", modifiers: .command)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasUnsavedChanges || loadError != nil)

                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape, modifiers: [])
                .controlSize(.small)
            }
            .padding(12)
            .background(Color(nsColor: .underPageBackgroundColor))

            Divider()

            if let loadError {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text(loadError)
                        .multilineTextAlignment(.center)
                    Button("Open in Default App") {
                        NSWorkspace.shared.open(item.url)
                        dismiss()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                TextEditor(text: $text)
                    .font(.system(size: 12.5, design: .monospaced))
                    .padding(6)
            }

            if let saveError {
                HStack {
                    Image(systemName: "xmark.octagon.fill")
                        .foregroundStyle(.red)
                    Text(saveError)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.red.opacity(0.1))
            }
        }
        .frame(minWidth: 740, minHeight: 540)
        .onAppear {
            loadFile()
        }
    }

    private func loadFile() {
        do {
            let data = try Data(contentsOf: item.url)
            if data.count > 2_000_000 {
                loadError = "File is larger than 2 MB. Use F3 Viewer or an external editor."
                return
            }
            if data.prefix(4096).contains(0) {
                loadError = "This appears to be a binary file and cannot be edited as plain text."
                return
            }
            guard let decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
                loadError = "Unable to decode text encoding for this file."
                return
            }
            text = decoded
            originalText = decoded
        } catch {
            loadError = "Could not read file: \(error.localizedDescription)"
        }
    }

    private func saveFile() {
        do {
            try text.write(to: item.url, atomically: true, encoding: .utf8)
            originalText = text
            saveError = nil
            onSaved()
        } catch {
            saveError = "Save failed: \(error.localizedDescription)"
        }
    }
}
