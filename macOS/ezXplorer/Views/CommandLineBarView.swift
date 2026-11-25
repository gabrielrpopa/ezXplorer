import SwiftUI

/// Integrated Norton Commander–style bottom shell prompt synced to the active pane's directory,
/// with a collapsible command output drawer.
struct CommandLineBarView: View {
    @ObservedObject var commander: CommanderViewModel
    @ObservedObject var shellRunner: ShellCommandRunner

    @State private var commandText: String = ""
    @State private var showOutputDrawer: Bool = false

    private var palette: ThemePalette { commander.palette }

    var body: some View {
        VStack(spacing: 0) {
            if showOutputDrawer {
                VStack(spacing: 0) {
                    HStack {
                        Text("Command Output")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        if shellRunner.isRunning {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Spacer()
                        if shellRunner.isRunning {
                            Button("Stop") {
                                shellRunner.cancelRunningCommand()
                            }
                            .controlSize(.mini)
                        }
                        Button("Clear") {
                            shellRunner.clearLog()
                        }
                        .controlSize(.mini)
                        Button {
                            showOutputDrawer = false
                        } label: {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .underPageBackgroundColor))

                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(shellRunner.outputLog.isEmpty ? "Run a shell command below (e.g. ls -la, git status, cd ..)." : shellRunner.outputLog)
                                .font(.system(size: 11.5, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .textSelection(.enabled)
                                .id("END_OF_LOG")
                        }
                        .onChange(of: shellRunner.outputLog) { _, _ in
                            proxy.scrollTo("END_OF_LOG", anchor: .bottom)
                        }
                    }
                    .frame(height: 145)
                    .background(Color(nsColor: .textBackgroundColor))
                }

                Divider()
            }

            HStack(spacing: 8) {
                Text(abbreviatedPath(commander.activePane.currentURL.path) + " $")
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(palette.isClassicTUI ? Color.yellow : Color.accentColor)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: 260, alignment: .trailing)

                TextField("Type a macOS shell command (supports cd, git, ls, open...)", text: $commandText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(palette.borderColor, lineWidth: 0.7)
                    )
                    .onSubmit {
                        submitCommand()
                    }

                if !shellRunner.commandHistory.isEmpty {
                    Menu {
                        ForEach(shellRunner.commandHistory.reversed(), id: \.self) { past in
                            Button(past) {
                                commandText = past
                            }
                        }
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 12))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 24)
                    .help("Command History")
                }

                Button("Run") {
                    submitCommand()
                }
                .controlSize(.small)
                .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || shellRunner.isRunning)

                Button {
                    showOutputDrawer.toggle()
                } label: {
                    Image(systemName: showOutputDrawer ? "terminal.fill" : "terminal")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help(showOutputDrawer ? "Hide Output Console" : "Show Output Console")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(palette.functionBarBackground)
        }
    }

    private func submitCommand() {
        let cmd = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cmd.isEmpty else { return }
        if !cmd.hasPrefix("cd") {
            showOutputDrawer = true
        }
        commander.executeCommandLine(cmd)
        commandText = ""
    }

    private func abbreviatedPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
