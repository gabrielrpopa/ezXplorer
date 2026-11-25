import SwiftUI

/// Iconic Norton Commander bottom function-key bar (F3 View through F10 Quit).
struct FunctionKeyBarView: View {
    @ObservedObject var commander: CommanderViewModel

    private var palette: ThemePalette { commander.palette }

    var body: some View {
        HStack(spacing: 4) {
            keyButton(key: "F3", label: "View") { commander.triggerViewFile() }
            keyButton(key: "F4", label: "Edit") { commander.triggerEditFile() }
            keyButton(key: "F5", label: "Copy") { commander.triggerCopy() }
            keyButton(key: "F6", label: "Move") { commander.triggerMove() }
            keyButton(key: "F7", label: "MkDir") { commander.triggerMakeDirectory() }
            keyButton(key: "F8", label: "Delete") { commander.triggerDelete() }
            keyButton(key: "F9", label: "Terminal") { commander.triggerOpenTerminal() }
            keyButton(key: "F10", label: "Quit") { commander.triggerQuit() }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(palette.functionBarBackground)
    }

    private func keyButton(key: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(key)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(palette.isClassicTUI ? Color.white : Color.secondary)
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold, design: palette.fontDesign))
                    .foregroundStyle(palette.functionKeyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(palette.functionKeyBadge)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
