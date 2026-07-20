//
//  AppMatcher.swift
//  KeepAwake
//
//  匹配当前正在运行的 App
//

import Cocoa

struct MatchResult {
    /// 匹配到的显示名列表
    let matchedNames: [String]
    /// 是否有任意一个目标 App 在运行
    var hasMatch: Bool { !matchedNames.isEmpty }
}

enum AppMatcher {
    /// 检查所有正在运行的应用，返回匹配到的目标 App 名称
    static func match(watchedApps: [WatchedApp]) -> MatchResult {
        let running = NSWorkspace.shared.runningApplications
        var hits: [String] = []
        var seen: Set<String> = []

        for app in running {
            guard let bundleId = app.bundleIdentifier,
                  let name = app.localizedName else { continue }

            for watched in watchedApps {
                var matched = false

                // 1. 优先精确匹配 bundleId
                if let wbId = watched.bundleId, wbId == bundleId {
                    matched = true
                }
                // 2. 没有 bundleId 时，按名字模糊匹配
                else if watched.bundleId == nil {
                    matched = name.localizedCaseInsensitiveContains(watched.name)
                }

                if matched && !seen.contains(watched.name) {
                    seen.insert(watched.name)
                    hits.append(watched.name)
                }
            }
        }
        return MatchResult(matchedNames: hits)
    }

    /// 查找资源文件路径（用于图标等资源）
    static func findResource(_ name: String, ext: String) -> String? {
        let fm = FileManager.default
        // 优先从 app bundle Resources 找
        if let bundlePath = Bundle.main.resourcePath {
            let path = (bundlePath as NSString).appendingPathComponent("\(name).\(ext)")
            if fm.fileExists(atPath: path) { return path }
        }
        // 再从 main bundle 的 executable 同一级目录找（开发时）
        if let execPath = Bundle.main.executablePath {
            let dir = (execPath as NSString).deletingLastPathComponent
            let path = (dir as NSString).appendingPathComponent("\(name).\(ext)")
            if fm.fileExists(atPath: path) { return path }
        }
        return nil
    }
}
