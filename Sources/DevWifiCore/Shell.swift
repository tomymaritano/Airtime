import Foundation

/// One finished command, or a command that never exited.
///
/// `finished` is false when the process does not start or is killed at the timeout.
/// A non-zero exit is still finished. `lsof` exits 1 when nothing matches, and that
/// empty listing is a real answer, not a failed probe.
public struct CommandOutput: Equatable, Sendable {
    public var text: String
    public var finished: Bool

    public init(text: String, finished: Bool) {
        self.text = text
        self.finished = finished
    }

    public static func finished(_ text: String) -> CommandOutput {
        CommandOutput(text: text, finished: true)
    }

    public static let failed = CommandOutput(text: "", finished: false)
}

enum Shell {
    static func run(_ launchPath: String, _ arguments: [String], timeout: TimeInterval? = nil) -> CommandOutput {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return .failed
        }

        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning, Date() < deadline {
                Thread.sleep(forTimeInterval: 0.04)
            }
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
                return .failed
            }
        } else {
            process.waitUntilExit()
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return .finished(text)
    }
}
