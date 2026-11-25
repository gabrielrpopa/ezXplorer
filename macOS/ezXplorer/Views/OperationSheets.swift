import SwiftUI

/// Modal confirmation and input sheets for Norton Commander / Explorer operations
/// (F5 Copy, F6 Move, Rename, F7 MkDir, New File, F8 Delete, and +/- Wildcard selection).
struct TransferOperationSheet: View {
    let title: String
    let verb: String
    let items: [FileItem]
    let initialDestination: URL
    let onConfirm: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var destinationPath: String = ""
    @State private var overwriteExisting: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Destination folder:")
                    .font(.caption.bold())
                TextField("Destination path", text: $destinationPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12, design: .monospaced))
                    .onSubmit { submit() }
            }

            Toggle("Overwrite existing files with the same name", isOn: $overwriteExisting)
                .font(.subheadline)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(verb) { submit() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .disabled(destinationPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 480)
        .onAppear {
            destinationPath = initialDestination.path
        }
    }

    private var summaryText: String {
        if items.count == 1, let first = items.first {
            return "\(verb) \"\(first.name)\" to:"
        }
        return "\(verb) \(items.count) selected items to:"
    }

    private func submit() {
        onConfirm(destinationPath, overwriteExisting)
        dismiss()
    }
}

struct SingleInputSheet: View {
    let title: String
    let subtitle: String
    let placeholder: String
    let initialValue: String
    let confirmLabel: String
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var inputText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            TextField(placeholder, text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { submit() }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(confirmLabel) { submit() }
                    .keyboardShortcut(.return, modifiers: [])
                    .buttonStyle(.borderedProminent)
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(18)
        .frame(width: 420)
        .onAppear {
            inputText = initialValue
        }
    }

    private func submit() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onConfirm(trimmed)
        dismiss()
    }
}

struct DeleteConfirmationSheet: View {
    let items: [FileItem]
    let onConfirm: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var deletePermanently: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: deletePermanently ? "trash.slash.fill" : "trash.fill")
                    .font(.title2)
                    .foregroundStyle(deletePermanently ? .red : .orange)
                Text(deletePermanently ? "Permanently Delete Items?" : "Move Items to Trash?")
                    .font(.headline)
            }

            if items.count == 1, let first = items.first {
                Text("Item: \"\(first.name)\"")
                    .font(.subheadline)
            } else {
                Text("\(items.count) items will be \(deletePermanently ? "permanently removed" : "moved to the Trash").")
                    .font(.subheadline)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(items.prefix(12)) { item in
                        Text("• \(item.name)")
                            .font(.system(size: 11.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    if items.count > 12 {
                        Text("...and \(items.count - 12) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 120)
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Toggle("Delete permanently (bypass Trash — cannot be undone)", isOn: $deletePermanently)
                .font(.caption)
                .foregroundStyle(deletePermanently ? .red : .primary)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
                Button(deletePermanently ? "Delete Permanently" : "Move to Trash", role: .destructive) {
                    onConfirm(deletePermanently)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: [])
                .buttonStyle(.borderedProminent)
                .tint(deletePermanently ? .red : .orange)
            }
        }
        .padding(18)
        .frame(width: 440)
    }
}
