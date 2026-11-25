# ezXplorer

A native **macOS SwiftUI + AppKit** file manager designed for Xcode that blends the best of **Norton Commander** (dual-pane, keyboard-first, function keys, integrated shell) and **Windows Explorer** (folder tree sidebar, breadcrumbs, live search filter, drag-and-drop, context menus, and preview inspector).

## Features

### Norton Commander–Inspired
- **Dual-Pane Layout**: Side-by-side Left and Right panels with active-pane indicator (`Tab` to switch, `⌘U` to swap panes, `⌘=` to equalize panes).
- **Classic Function Key Bar**:
  - `F3` **View** — Built-in text, image, and automatic binary hex-dump viewer with line search.
  - `F4` **Edit** — Built-in lightweight text editor with `⌘S` Save and Revert.
  - `F5` **Copy** — Directional copy from active pane to opposite pane (with overwrite toggle).
  - `F6` **Move** — Directional move from active pane to opposite pane.
  - `F7` **MkDir** — Create new folders (including nested paths).
  - `F8` **Delete** — Safe Move to Trash by default, with optional Permanent Delete.
  - `F9` **Terminal** — Launch macOS Terminal.app directly in the active folder.
  - `F10` **Quit** — Exit the app.
- **Keyboard-First Navigation**: `↑`/`↓`/`Home`/`End`/`PageUp`/`PageDown`, `Return` to open, `Backspace` to ascend (`..` parent entry), `Space` to mark/unmark files and advance, and `+` / `-` for wildcard glob selection (`*.swift`, `report_?.pdf`).
- **Directory Compare**: Highlights files that are unique (`NEW`) or newer (`MOD`) across Left and Right panes and marks them for one-keystroke synchronization.
- **Integrated Bottom Command Line**: Synced to the active pane's working directory; supports built-in `cd` navigation and runs arbitrary `/bin/zsh` commands with a collapsible output console and history menu.
- **Switchable Themes**: **macOS Native**, **Norton Classic Blue**, and **Midnight Dark**.

### Windows Explorer–Inspired
- **Collapsible Sidebar Tree**: Quick Access (Home, Desktop, Documents, Downloads, Applications, Root `/`), user-pinned Favorites, Mounted Drives/Volumes, and a lazy-loaded expandable Folder Tree.
- **Breadcrumb & Editable Address Bar**: Click any path segment to jump, double-click (or click the pencil button) to type paths directly (supports `~`), plus Back / Forward / Up / Refresh navigation buttons.
- **Single-Pane / Dual-Pane Toggle**: Switch instantly between Commander dual-pane and Explorer single-pane modes.
- **Sortable Columns & Live Filter**: Click Name, Ext, Size, or Modified headers to sort (folders always grouped first) and filter items in real time.
- **Drag-and-Drop & Context Menus**: Drag files between panes or from Finder (hold `⌘` to move), and right-click for Open, View, Edit, Copy/Move, Rename, Duplicate, Copy Path, Reveal in Finder, Open in Terminal, and Trash.
- **Preview Inspector**: Optional right-side panel showing thumbnails, text snippets, file sizes, timestamps, and POSIX permissions.

## Requirements
- **macOS 14.0 (Sonoma)** or later
- **Xcode 15.0** or later (Swift 5.9+)

## How to Build & Run on macOS

### Option 1: Open the Xcode Project (Recommended)
1. Copy or clone the `ezXplorer` directory onto your Mac.
2. Double-click `ezXplorer.xcodeproj` to open it in Xcode.
3. Select the **ezXplorer** scheme and target **My Mac**.
4. Press **`⌘R`** to build and run (each build also generates `dist/ezXplorer.dmg` automatically).

### Option 2: Swift Package Manager
```bash
cd ezXplorer
swift run
```
(Or open `Package.swift` directly in Xcode.)

## Permissions & Sandbox Note
`ezXplorer.entitlements` disables App Sandbox (`com.apple.security.app-sandbox = false`) so the utility can freely browse local directories, external volumes, and execute shell commands from the integrated prompt. macOS may still prompt once for **Files and Folders** access when visiting protected folders such as Desktop, Documents, or Downloads.

> **Tip for macOS Function Keys**: If your Mac uses `F3`–`F10` for media/Mission Control by default, hold **`Fn`** while pressing `F3`–`F10`, enable *"Use F1, F2, etc. keys as standard function keys"* in **System Settings → Keyboard → Keyboard Shortcuts → Function Keys**, or click the bottom function-key buttons directly.
