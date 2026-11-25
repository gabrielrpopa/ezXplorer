import SwiftUI

/// Windows Explorer–style navigation sidebar with Quick Access, Favorites,
/// Mounted Volumes, and a lazy expandable folder tree.
struct SidebarTreeView: View {
    @ObservedObject var commander: CommanderViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("QUICK ACCESS")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(commander.quickAccess) { loc in
                        sidebarButton(title: loc.title, systemImage: loc.systemImage, url: loc.url)
                    }
                }

                HStack {
                    sectionHeader("FAVORITES")
                    Spacer()
                    Button {
                        commander.addActiveFolderToFavorites()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Bookmark active folder")
                }

                if commander.favorites.isEmpty {
                    Text("Click + to pin current folder")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(commander.favorites) { fav in
                            sidebarButton(title: fav.title, systemImage: fav.systemImage, url: fav.url)
                                .contextMenu {
                                    Button("Remove Favorite", role: .destructive) {
                                        commander.removeFavorite(fav)
                                    }
                                }
                        }
                    }
                }

                sectionHeader("DRIVES & VOLUMES")
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(commander.volumes) { vol in
                        sidebarButton(title: vol.title, systemImage: vol.systemImage, url: vol.url)
                    }
                }

                sectionHeader("FOLDER TREE")
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(commander.treeRoots) { root in
                        DirectoryTreeNodeRow(
                            node: root,
                            depth: 0,
                            activeURL: commander.activePane.currentURL,
                            showHidden: commander.showHiddenFiles,
                            onSelect: { url in
                                commander.activePane.navigate(to: url)
                            }
                        )
                    }
                }
            }
            .padding(10)
        }
        .frame(minWidth: 190, idealWidth: 220, maxWidth: 300)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
    }

    private func sidebarButton(title: String, systemImage: String, url: URL) -> some View {
        let isSelected = commander.activePane.currentURL.standardizedFileURL == url.standardizedFileURL
        return Button {
            commander.activePane.navigate(to: url)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                    .frame(width: 16)
                Text(title)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(isSelected ? Color.white : Color.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.accentColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct DirectoryTreeNodeRow: View {
    @ObservedObject var node: DirectoryTreeNode
    let depth: Int
    let activeURL: URL
    let showHidden: Bool
    let onSelect: (URL) -> Void

    var body: some View {
        let isSelected = activeURL.standardizedFileURL == node.url.standardizedFileURL

        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Button {
                    node.toggleExpanded(showHidden: showHidden)
                } label: {
                    Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    onSelect(node.url)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: node.systemImage)
                            .font(.system(size: 11.5))
                            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                        Text(node.name)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .foregroundStyle(isSelected ? Color.white : Color.primary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .background(isSelected ? Color.accentColor : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.leading, CGFloat(depth) * 14)

            if node.isExpanded {
                ForEach(node.children) { child in
                    DirectoryTreeNodeRow(
                        node: child,
                        depth: depth + 1,
                        activeURL: activeURL,
                        showHidden: showHidden,
                        onSelect: onSelect
                    )
                }
            }
        }
    }
}
