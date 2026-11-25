import Foundation

struct ShellCommandResult {
    let command: String
    let workingDirectory: URL
    let output: String
    let exitCode: Int32
    let timestamp: Date
}

/// Runs shell commands from the integrated Norton Commander–style bottom command prompt.
@MainActor
final class ShellCommandRunner: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var outputLog: String = ""
    @Published var commandHistory: [String] = []
    @Published var lastExitCode: Int32 = 0

    private var activeProcess: Process?

    func run(command: String, in directory: URL, completion: (() -> Void)? = nil) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if commandHistory.last != trimmed {
            commandHistory.append(trimmed)
        }

        isRunning = true
        let promptHeader = "\n[\(directory.lastPathComponent)] $ \(trimmed)\n"
        outputLog.append(promptHeader)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", trimmed]
        process.currentDirectoryURL = directory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        activeProcess = process

        Task.detached { [weak self] in
            var captured = ""
            var status: Int32 = -1
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                status = process.terminationStatus
                captured = String(data: data, encoding: .utf8) ?? ""
            } catch {
                captured = "Error executing command: \(error.localizedDescription)\n"
            }

            await MainActor.run {
                guard let self else { return }
                if !captured.isEmpty {
                    self.outputLog.append(captured)
                    if !captured.hasSuffix("\n") {
                        self.outputLog.append("\n")
                    }
                }
                self.lastExitCode = status
                self.isRunning = false
                self.activeProcess = nil
                completion?()
            }
        }
    }

    func cancelRunningCommand() {
        activeProcess?.terminate()
        activeProcess = nil
        isRunning = false
        outputLog.append("^C (Terminated)\n")
    }

    func clearLog() {
        outputLog = ""
    }
}
