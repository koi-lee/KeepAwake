import Foundation

enum LoginItemManager {
    private static let label = "com.starshoreai.keepawake"
    static var launchAgentURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }
    static var isEnabled: Bool { FileManager.default.fileExists(atPath: launchAgentURL.path) }
    @discardableResult static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try FileManager.default.createDirectory(at: launchAgentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                let executable = Bundle.main.executableURL?.path ?? "/Applications/KeepAwake.app/Contents/MacOS/KeepAwake"
                let plist: [String: Any] = ["Label": label, "ProgramArguments": [executable], "RunAtLoad": true, "KeepAlive": false, "ProcessType": "Interactive"]
                let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
                try data.write(to: launchAgentURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: launchAgentURL.path) {
                try FileManager.default.removeItem(at: launchAgentURL)
            }
            return true
        } catch {
            print("[KeepAwake] 开机启动配置失败: \(error)")
            return false
        }
    }
}
