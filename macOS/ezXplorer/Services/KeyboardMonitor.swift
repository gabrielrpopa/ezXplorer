import AppKit

/// Intercepts Norton Commander keyboard shortcuts at the AppKit window level while staying out
/// of the way whenever a text field, search box, or modal sheet is active.
final class KeyboardMonitor {
    private var monitor: Any?

    enum KeyAction {
        case switchPane
        case moveUp
        case moveDown
        case moveHome
        case moveEnd
        case pageUp
        case pageDown
        case openSelected
        case goParent
        case toggleSelection
        case renameItem     // F2
        case viewFile       // F3
        case editFile       // F4
        case copyItems      // F5
        case moveItems      // F6
        case makeDirectory  // F7
        case deleteItems    // F8 / Forward Delete
        case openTerminal   // F9
        case quitApp        // F10
        case wildcardSelect // +
        case wildcardDeselect // -
    }

    func start(handler: @escaping (KeyAction) -> Bool) {
        stop()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Ignore key events when a sheet/modal window is active or user is typing in a text editor/field.
            guard let keyWindow = NSApp.keyWindow, keyWindow.attachedSheet == nil else {
                return event
            }
            if keyWindow.firstResponder is NSText || keyWindow.firstResponder is NSTextField {
                return event
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let hasCmdOrCtrl = modifiers.contains(.command) || modifiers.contains(.control) || modifiers.contains(.option)

            // Allow plain keys and function keys (ignore Cmd/Ctrl/Option combos handled by SwiftUI menus).
            if hasCmdOrCtrl {
                return event
            }

            let action: KeyAction?
            switch event.keyCode {
            case 48: action = .switchPane       // Tab
            case 126: action = .moveUp          // Up Arrow
            case 125: action = .moveDown        // Down Arrow
            case 115: action = .moveHome        // Home
            case 119: action = .moveEnd         // End
            case 116: action = .pageUp          // Page Up
            case 121: action = .pageDown        // Page Down
            case 36, 76: action = .openSelected // Return / Enter
            case 51: action = .goParent         // Backspace / Delete
            case 49: action = .toggleSelection  // Space (multi-select like NC Insert)
            case 120: action = .renameItem      // F2 (Windows Explorer inline rename)
            case 99: action = .viewFile         // F3
            case 118: action = .editFile        // F4
            case 96: action = .copyItems        // F5
            case 97: action = .moveItems        // F6
            case 98: action = .makeDirectory    // F7
            case 100, 117: action = .deleteItems // F8 or Forward Delete
            case 101: action = .openTerminal    // F9
            case 109: action = .quitApp         // F10
            default:
                if event.charactersIgnoringModifiers == "+" {
                    action = .wildcardSelect
                } else if event.charactersIgnoringModifiers == "-" {
                    action = .wildcardDeselect
                } else {
                    action = nil
                }
            }

            if let action, handler(action) {
                return nil
            }
            return event
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    deinit {
        stop()
    }
}
