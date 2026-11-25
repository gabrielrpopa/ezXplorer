import SwiftUI

/// Windows Explorer–style navigation bar: Back/Forward/Up buttons, clickable breadcrumbs,
/// editable path bar, and live folder filter.
struct BreadcrumbBarView: View {
    @ObservedObject var pane: PaneViewModel
    let isActive: Bool
    let palette: ThemePalette
    let onActivate: () -> Void

    @State private var typedPath: String = ""
    @FocusState private var pathFieldFocused: Bool

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                // Navigation buttons (Explorer style)
                HStack(spacing: 2) {
                    navButton(systemImage: "chevron.left", help: "Back", enabled: pane.canGoBack) {
                        onActivate()
                        pane.goBack()
                    }
                    navButton(systemImage: "chevron.right", help: "Forward", enabled: pane.canGoForward) {
                        onActivate()
                        pane.goForward()
                    }
                    navButton(systemImage: "arrow.up", help: "Up One Level (Backspace)", enabled: pane.canGoUp) {
                        onActivate()
                        pane.goUp()
                    }
                    navButton(systemImage: "arrow.clockwise", help: "Refresh", enabled: true) {
                        onActivate()
                        pane.refresh()
                    }
                }

                // Breadcrumb / Editable path address bar
                if pane.isEditingPath {
                    HStack(spacing: 4) {
                        TextField("Enter path (e.g. ~/Documents)", text: $typedPath)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                            .focused($pathFieldFocused)
                            .onSubmit {
                                pane.navigateFromTypedPath(typedPath)
                                pane.isEditingPath = false
                            }
                            .onExitCommand {
                                pane.isEditingPath = false
                            }

                        Button {
                            pane.isEditingPath = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(palette.activeHeaderAccent, lineWidth: 1.5)
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {
                            ForEach(Array(pane.pathComponents.enumerated()), id: \.offset) { index, segment in
                                if index > 0 {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundStyle(palette.isClassicTUI ? Color.white.opacity(0.65) : Color.secondary)
                                }
                                Button {
                                    onActivate()
                                    pane.navigate(to: segment.url)
                                } label: {
                                    Text(segment.title)
                                        .font(.system(size: 11.5, weight: index == pane.pathComponents.count - 1 ? .semibold : .regular, design: palette.fontDesign))
                                        .foregroundStyle(palette.isClassicTUI ? Color.white : Color.primary)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(
                                            index == pane.pathComponents.count - 1
                                            ? (isActive ? palette.activeHeaderAccent.opacity(0.28) : Color.clear)
                                            : Color.clear
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                    .frame(height: 24)
                    .background(
                        palette.isClassicTUI
                            ? (isActive ? palette.activeHeaderAccent.opacity(0.45) : palette.headerBackground.opacity(0.75))
                            : Color(nsColor: .textBackgroundColor).opacity(0.7)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(isActive ? palette.activeHeaderAccent : palette.borderColor, lineWidth: isActive ? 1.5 : 0.8)
                    )
                    .onTapGesture(count: 2) {
                        beginPathEdit()
                    }
                }

                // Toggle path edit button
                Button {
                    if pane.isEditingPath {
                        pane.isEditingPath = false
                    } else {
                        beginPathEdit()
                    }
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 11))
                        .foregroundStyle(palette.isClassicTUI ? Color.white : Color.primary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Edit path directly")

                // Explorer-style live search/filter input
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    TextField("Filter", text: $pane.filterText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 11.5))
                        .frame(width: 95)
                    if !pane.filterText.isEmpty {
                        Button {
                            pane.filterText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(palette.borderColor, lineWidth: 0.7)
                )
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(palette.headerBackground)
    }

    private func beginPathEdit() {
        onActivate()
        typedPath = pane.currentURL.path
        pane.isEditingPath = true
        DispatchQueue.main.async {
            pathFieldFocused = true
        }
    }

    private func navButton(systemImage: String, help: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(
                    enabled
                    ? (palette.isClassicTUI ? Color.white : Color.primary)
                    : Color.secondary.opacity(0.4)
                )
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(help)
    }
}
