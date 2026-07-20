//
//  AppConfig.swift
//  KeepAwake
//
//  配置模型：从 ~/.keepawake.json 读取
//

import Foundation
import Cocoa

struct WatchedApp: Codable, Equatable {
    /// 显示名，用于按名字模糊匹配
    let name: String
    /// 包标识符，精确匹配；nil 则只靠名字匹配
    let bundleId: String?
}

struct AppConfig: Codable {
    let watchedApps: [WatchedApp]
    let checkInterval: Double   // 秒
    let showNotifications: Bool

    static let `default` = AppConfig(
        watchedApps: [
            WatchedApp(name: "ChatGPT", bundleId: "com.openai.chat"),
            WatchedApp(name: "ChatGPT", bundleId: "com.openai.codex"),
            WatchedApp(name: "ChatGPT", bundleId: nil)  // 兜底：按名字匹配
        ],
        checkInterval: 5.0,
        showNotifications: true
    )
}

enum ConfigLoader {
    static var configPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".keepawake.json")
    }

    /// 启动时预加载配置，AppDelegate 启动时从这里取
    static var liveConfig: AppConfig = load()

    static func load() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configPath.path) else {
            return .default
        }
        guard let data = try? Data(contentsOf: configPath),
              let cfg = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .default
        }
        return cfg
    }

    /// 确保配置文件存在（不存在则写入默认配置并打开编辑器）
    static func ensureConfigExists() {
        if !FileManager.default.fileExists(atPath: configPath.path) {
            if let data = try? JSONEncoder().encode(AppConfig.default) {
                try? data.write(to: configPath)
            }
        }
    }

    static func openInEditor() {
        ensureConfigExists()
        NSWorkspace.shared.open(configPath)
    }
    
    /// 保存配置到文件
    static func saveConfig(_ config: AppConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(config) {
            try? data.write(to: configPath)
        }
        // 刷新 liveConfig
        liveConfig = config
    }
}
