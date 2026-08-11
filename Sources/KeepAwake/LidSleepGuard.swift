import Foundation

private enum LidSleepGuardError: LocalizedError {
    case authorizationFailed
    case authorizationTimedOut

    var errorDescription: String? {
        switch self {
        case .authorizationFailed: return "管理员授权未完成或 pmset 启动失败"
        case .authorizationTimedOut: return "等待管理员授权超时"
        }
    }
}

/// 使用 macOS 的 pmset 管理员授权阻止合盖睡眠。
/// 这是独立于 IOKit 空闲睡眠断言的第二层守护。
final class LidSleepGuard {
    private var process: Process?
    private var readyURL: URL?
    private var stopURL: URL?

    var isActive: Bool { process?.isRunning == true }

    func start() throws {
        guard !isActive else { return }
        let token = UUID().uuidString
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeepAwake-\(ProcessInfo.processInfo.processIdentifier)-\(token)")
        let ready = base.appendingPathExtension("ready")
        let stopMarker = base.appendingPathExtension("stop")
        let command = shellCommand(ready: ready, stop: stopMarker)
        let escaped = command.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "with timeout of 2147483647 seconds\n do shell script \"\(escaped)\" with administrator privileges\nend timeout"

        try? FileManager.default.removeItem(at: ready)
        try? FileManager.default.removeItem(at: stopMarker)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try process.run()
        self.process = process
        self.readyURL = ready
        self.stopURL = stopMarker

        let deadline = Date().addingTimeInterval(120)
        while process.isRunning && Date() < deadline {
            if FileManager.default.fileExists(atPath: ready.path) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        if process.isRunning {
            stop()
            throw LidSleepGuardError.authorizationTimedOut
        }
        self.process = nil
        discardSessionFiles()
        throw LidSleepGuardError.authorizationFailed
    }

    func stop() {
        guard let process else { return }
        if process.isRunning, let stopURL {
            FileManager.default.createFile(atPath: stopURL.path, contents: Data())
            let deadline = Date().addingTimeInterval(2)
            while process.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            if process.isRunning { process.terminate() }
        }
        self.process = nil
        discardSessionFiles()
    }

    private func discardSessionFiles() {
        if let readyURL { try? FileManager.default.removeItem(at: readyURL) }
        if let stopURL { try? FileManager.default.removeItem(at: stopURL) }
        self.readyURL = nil
        self.stopURL = nil
    }

    private func shellCommand(ready: URL, stop: URL) -> String {
        let readyPath = shellQuote(ready.path)
        let stopPath = shellQuote(stop.path)
        return [
            "original_state=0",
            "/usr/bin/pmset -g | /usr/bin/grep -Eq 'SleepDisabled[[:space:]]+1' && original_state=1",
            "cleanup() { /usr/bin/pmset -a disablesleep \"$original_state\"; /bin/rm -f \(readyPath) \(stopPath); }",
            "trap cleanup 0 1 2 15",
            "/usr/bin/pmset -a disablesleep 1 || exit 1",
            "/usr/bin/touch \(readyPath) || exit 1",
            "while /bin/kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null && [ ! -e \(stopPath) ]; do /usr/bin/pmset -g | /usr/bin/grep -Eq 'SleepDisabled[[:space:]]+1' || /usr/bin/pmset -a disablesleep 1; /bin/sleep 1; done"
        ].joined(separator: "; ")
    }

    private func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
