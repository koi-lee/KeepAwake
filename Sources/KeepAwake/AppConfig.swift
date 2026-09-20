//
//  AppConfig.swift
//  KeepAwake
//
//  配置模型：从 Application Support 读取
//

import Foundation
import Cocoa

struct WatchedApp: Codable, Equatable {
    /// 显示名，用于按名字模糊匹配
    let name: String
    /// 包标识符，精确匹配；nil 则只靠名字匹配
    let bundleId: String?
}

enum SleepMode: String, Codable, CaseIterable {
    case system
    case display
    case lid

    var title: String {
        switch self {
        case .system: return "阻止系统睡眠中（屏幕可熄）"
        case .display: return "阻止屏幕睡眠中（屏幕常亮）"
        case .lid: return "合盖保活（需要管理员授权）"
        }
    }

    var shortTitle: String {
        switch self {
        case .system: return "阻止系统睡眠（屏幕可熄）"
        case .display: return "阻止屏幕睡眠（屏幕常亮）"
        case .lid: return "合盖保活"
        }
    }
}

struct AppConfig: Codable {
    static let currentVersion = 2
    static let defaultLogSizeLimitBytes = 1024 * 1024

    var configVersion: Int
    var watchedApps: [WatchedApp]
    var checkInterval: Double   // 秒
    var showNotifications: Bool
    var sleepMode: SleepMode
    var defaultDurationMinutes: Int
    var lowBatteryThreshold: Int
    var onlyOnPower: Bool
    var logSizeLimitBytes: Int

    private enum CodingKeys: String, CodingKey {
        case configVersion
        case watchedApps
        case checkInterval
        case showNotifications
        case sleepMode
        case defaultDurationMinutes
        case lowBatteryThreshold
        case onlyOnPower
        case logSizeLimitBytes
    }

    init(
        configVersion: Int = AppConfig.currentVersion,
        watchedApps: [WatchedApp],
        checkInterval: Double,
        showNotifications: Bool,
        sleepMode: SleepMode = .system,
        defaultDurationMinutes: Int = 60,
        lowBatteryThreshold: Int = 20,
        onlyOnPower: Bool = false,
        logSizeLimitBytes: Int = AppConfig.defaultLogSizeLimitBytes
    ) {
        self.configVersion = configVersion
        self.watchedApps = watchedApps
        self.checkInterval = checkInterval
        self.showNotifications = showNotifications
        self.sleepMode = sleepMode
        self.defaultDurationMinutes = defaultDurationMinutes
        self.lowBatteryThreshold = lowBatteryThreshold
        self.onlyOnPower = onlyOnPower
        self.logSizeLimitBytes = logSizeLimitBytes
    }

    // V1 配置没有 V2 字段。缺失字段使用安全默认值，随后由 ConfigLoader 写回 V2。
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        configVersion = try container.decodeIfPresent(Int.self, forKey: .configVersion) ?? 1
        watchedApps = try container.decodeIfPresent([WatchedApp].self, forKey: .watchedApps) ?? []
        checkInterval = try container.decodeIfPresent(Double.self, forKey: .checkInterval) ?? 5.0
        showNotifications = try container.decodeIfPresent(Bool.self, forKey: .showNotifications) ?? true
        sleepMode = try container.decodeIfPresent(SleepMode.self, forKey: .sleepMode) ?? .system
        defaultDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .defaultDurationMinutes) ?? 60
        lowBatteryThreshold = try container.decodeIfPresent(Int.self, forKey: .lowBatteryThreshold) ?? 20
        onlyOnPower = try container.decodeIfPresent(Bool.self, forKey: .onlyOnPower) ?? false
        logSizeLimitBytes = try container.decodeIfPresent(Int.self, forKey: .logSizeLimitBytes) ?? AppConfig.defaultLogSizeLimitBytes
    }

    static let `default` = AppConfig(
        watchedApps: [],
        checkInterval: 5.0,
        showNotifications: true
    )

    static func logSizeLimitKB(_ bytes: Int) -> Int { max(64, bytes / 1024) }
}

enum ConfigLoader {
    static var hasPersistedConfig: Bool {
        let fileManager = FileManager.default
        return fileManager.fileExists(atPath: configPath.path) ||
            fileManager.fileExists(atPath: legacyConfigPath.path)
    }

    static var storageDirectory: URL {
        let baseDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return baseDirectory.appendingPathComponent("KeepAwake", isDirectory: true)
    }

    static var configPath: URL {
        storageDirectory.appendingPathComponent("config.json")
    }

    static var legacyConfigPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".keepawake.json")
    }

    static var networkLogPath: URL {
        storageDirectory
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("network.log")
    }

    /// 启动时预加载配置，AppDelegate 启动时从这里取
    static var liveConfig: AppConfig = load()

    static func load() -> AppConfig {
        let fileManager = FileManager.default
        let sourceURL: URL
        if fileManager.fileExists(atPath: configPath.path) {
            sourceURL = configPath
        } else if fileManager.fileExists(atPath: legacyConfigPath.path) {
            sourceURL = legacyConfigPath
        } else {
            return .default
        }

        guard let data = try? Data(contentsOf: sourceURL),
              var cfg = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }

        var needsSave = sourceURL != configPath || cfg.configVersion != AppConfig.currentVersion
        if cfg.configVersion != AppConfig.currentVersion {
            cfg.configVersion = AppConfig.currentVersion
        }

        if cfg.checkInterval < 1 {
            cfg.checkInterval = AppConfig.default.checkInterval
            needsSave = true
        }
        if !(0...100).contains(cfg.lowBatteryThreshold) {
            cfg.lowBatteryThreshold = AppConfig.default.lowBatteryThreshold
            needsSave = true
        }
        if cfg.defaultDurationMinutes < 1 {
            cfg.defaultDurationMinutes = AppConfig.default.defaultDurationMinutes
            needsSave = true
        }
        if cfg.logSizeLimitBytes < 64 * 1024 {
            cfg.logSizeLimitBytes = AppConfig.defaultLogSizeLimitBytes
            needsSave = true
        }
        if needsSave {
            _ = saveConfig(cfg)
        }
        return cfg
    }

    /// 确保配置文件存在（不存在则写入默认配置并打开编辑器）
    static func ensureConfigExists() {
        let fileManager = FileManager.default
        try? fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: configPath.path) {
            if let legacyData = try? Data(contentsOf: legacyConfigPath) {
                try? legacyData.write(to: configPath, options: .atomic)
                return
            }
            if let data = try? JSONEncoder().encode(AppConfig.default) {
                try? data.write(to: configPath)
            }
        }
    }

    static func openInEditor() {
        ensureConfigExists()
        // Do not rely on the user's .json file association. Some machines
        // associate JSON with a development tool (for example, WeChat DevTools),
        // which is surprising for this menu action. Use TextEdit as the safe,
        // built-in fallback editor and keep the system association as a fallback
        // for environments where TextEdit is unavailable.
        let textEditURL = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        if FileManager.default.fileExists(atPath: textEditURL.path) {
            NSWorkspace.shared.open(
                [configPath],
                withApplicationAt: textEditURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
        NSWorkspace.shared.open(configPath)
    }
    
    /// 保存配置到文件
    @discardableResult
    static func saveConfig(_ config: AppConfig) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            let data = try encoder.encode(config)
            try FileManager.default.createDirectory(
                at: storageDirectory,
                withIntermediateDirectories: true
            )
            try data.write(to: configPath, options: .atomic)
            liveConfig = config
            return true
        } catch {
            print("[KeepAwake] 保存配置失败: \(error)")
            return false
        }
    }
}
