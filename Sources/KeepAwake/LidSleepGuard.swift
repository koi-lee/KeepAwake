import Foundation

private enum LidSleepGuardError: LocalizedError {
    case authorizationFailed(String)
    case authorizationTimedOut

    var errorDescription: String? {
        switch self {
        case .authorizationFailed(let detail): return detail
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
        let termination = process.terminationStatus
        self.process = nil
        discardSessionFiles()
        throw LidSleepGuardError.authorizationFailed(Self.failureMessage(for: termination))
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

    static func failureMessage(for terminationStatus: Int32) -> String {
        guard terminationStatus != 0 else {
            return "管理员授权命令已结束，但合盖保活未能启动。请重试；如果仍失败，请检查 macOS 是否允许 KeepAwake 请求管理员权限。"
        }
        return "管理员授权未完成（授权对话框被取消或系统命令执行失败，退出码：\(terminationStatus)）。请在系统密码对话框中输入 Mac 登录密码并点击“好”，不要输入 Apple 账户密码；如果未出现密码框，请检查系统是否拦截了授权请求。"
    }
}
