import SwiftUI
import AppKit

/// AppKit-backed inline text field that mimics Windows 11 File Explorer & macOS Finder inline renaming:
/// focuses automatically, pre-selects the full folder name (or file base name excluding extension),
/// commits on Return or focus loss, and cancels on Escape.
struct InlineRenameTextField: NSViewRepresentable {
    let initialText: String
    let isDirectory: Bool
    let fontDesign: Font.Design
    let onCommit: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isDirectory: isDirectory, onCommit: onCommit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: initialText)
        field.delegate = context.coordinator
        field.isBordered = true
        field.isBezeled = true
        field.bezelStyle = .squareBezel
        field.drawsBackground = true
        field.backgroundColor = NSColor.textBackgroundColor
        field.textColor = NSColor.labelColor
        field.focusRingType = .default
        field.lineBreakMode = .byTruncatingHead
        field.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        field.font = fontDesign == .monospaced
            ? NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            : NSFont.systemFont(ofSize: 12, weight: isDirectory ? .semibold : .regular)

        context.coordinator.scheduleInitialSelection(for: field)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.onCommit = onCommit
        context.coordinator.onCancel = onCancel
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        let isDirectory: Bool
        var onCommit: (String) -> Void
        var onCancel: () -> Void
        private var didStartEditing = false
        private var didFinish = false

        init(isDirectory: Bool, onCommit: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
            self.isDirectory = isDirectory
            self.onCommit = onCommit
            self.onCancel = onCancel
        }

        func scheduleInitialSelection(for field: NSTextField) {
            guard !didStartEditing else { return }
            DispatchQueue.main.async { [weak self, weak field] in
                guard let self, let field, !self.didStartEditing, !self.didFinish else { return }
                guard let window = field.window else {
                    // Retry once on next runloop tick if SwiftUI hasn't attached to window yet.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self, weak field] in
                        guard let self, let field else { return }
                        self.activateAndSelect(field)
                    }
                    return
                }
                _ = window
                self.activateAndSelect(field)
            }
        }

        private func activateAndSelect(_ field: NSTextField) {
            guard !didStartEditing, !didFinish, let window = field.window else { return }
            didStartEditing = true
            window.makeFirstResponder(field)

            let text = field.stringValue as NSString
            let selectionLength: Int
            if isDirectory {
                selectionLength = text.length
            } else {
                let lastDot = text.range(of: ".", options: .backwards)
                // Select base name before extension (keep full name for hidden dotfiles like ".env")
                if lastDot.location != NSNotFound && lastDot.location > 0 {
                    selectionLength = lastDot.location
                } else {
                    selectionLength = text.length
                }
            }

            if let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: 0, length: selectionLength)
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                finishCommit(with: control.stringValue)
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                finishCancel()
                return true
            }
            return false
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            finishCommit(with: field.stringValue)
        }

        private func finishCommit(with value: String) {
            guard !didFinish else { return }
            didFinish = true
            let committed = value
            DispatchQueue.main.async { [onCommit] in
                onCommit(committed)
            }
        }

        private func finishCancel() {
            guard !didFinish else { return }
            didFinish = true
            DispatchQueue.main.async { [onCancel] in
                onCancel()
            }
        }
    }
}
