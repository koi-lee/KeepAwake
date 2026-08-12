//
//  SleepGuard.swift
//  KeepAwake
//
//  IOKit 电源断言：阻止系统空闲睡眠 / 屏幕睡眠
//

import Foundation
import IOKit.pwr_mgt
import Network

final class NetworkPathLogger {
    static let logURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Logs/KeepAwake/network.log")

    private let queue = DispatchQueue(label: "com.keepawake.network-path-logger")
    private var monitor: NWPathMonitor?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            self?.write(pathDescription(path))
        }
        self.monitor = monitor
        write("诊断开始")
        monitor.start(queue: queue)
    }

    func stop() {
        guard let monitor else { return }
        write("诊断结束")
        monitor.cancel()
        self.monitor = nil
    }

    static func ensureLogExists() {
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
    }

    private func write(_ message: String) {
        queue.async {
            Self.ensureLogExists()
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let line = "\(formatter.string(from: Date())) \(message)\n"
            guard let data = line.data(using: .utf8),
                  let handle = try? FileHandle(forWritingTo: Self.logURL) else { return }
            defer { try? handle.close() }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                print("[KeepAwake] 写入网络诊断日志失败: \(error)")
            }
        }
    }
}

private func pathDescription(_ path: NWPath) -> String {
    let status: String
    switch path.status {
    case .satisfied: status = "可用"
    case .requiresConnection: status = "需要连接"
    case .unsatisfied: status = "不可用"
    @unknown default: status = "未知"
    }
    let interfaces: [(NWInterface.InterfaceType, String)] = [
        (.wifi, "Wi-Fi"), (.wiredEthernet, "有线网络"), (.cellular, "蜂窝网络"), (.loopback, "本机"), (.other, "其他")
    ]
    let activeInterfaces = interfaces.compactMap { path.usesInterfaceType($0.0) ? $0.1 : nil }
    let interfaceText = activeInterfaces.isEmpty ? "无" : activeInterfaces.joined(separator: ",")
    return "网络=\(status) 接口=\(interfaceText) DNS=\(path.supportsDNS ? "可用" : "不可用") 受限=\(path.isConstrained ? "是" : "否") 高成本=\(path.isExpensive ? "是" : "否")"
}

/// 睡眠守卫者
/// - 调用 `prevent(reason:)` → 阻止系统空闲睡眠
/// - 调用 `allow()` → 释放断言，恢复正常睡眠行为
final class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private var networkAssertionID: IOPMAssertionID = 0
    private(set) var isActive: Bool = false
    private let lidGuard = LidSleepGuard()
    private let networkLogger = NetworkPathLogger()

    /// 阻止系统空闲睡眠（系统不会因空闲而进入睡眠，但合盖仍会睡眠）
    @discardableResult
    func prevent(reason: String, keepLidAwake: Bool = false) -> Bool {
        guard !isActive else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            if keepLidAwake {
                do {
                    try lidGuard.start()
                } catch {
                    IOPMAssertionRelease(assertionID)
                    assertionID = 0
                    print("[KeepAwake] 合盖保活授权失败: \(error)")
                    return false
                }
                let networkResult = IOPMAssertionCreateWithName(
                    kIOPMAssertNetworkClientActive as CFString,
                    IOPMAssertionLevel(kIOPMAssertionLevelOn),
                    "\(reason) · 网络保活" as CFString,
                    &networkAssertionID
                )
                if networkResult != kIOReturnSuccess {
                    lidGuard.stop()
                    IOPMAssertionRelease(assertionID)
                    assertionID = 0
                    networkAssertionID = 0
                    print("[KeepAwake] 网络保活断言失败，IOReturn: \(networkResult)")
                    return false
                }
                networkLogger.start()
            }
            isActive = true
            print("[KeepAwake] 已阻止系统睡眠 (reason: \(reason))")
            return true
        } else {
            print("[KeepAwake] 阻止睡眠失败，IOReturn: \(result)")
            return false
        }
    }

    /// 阻止屏幕睡眠（屏幕也不会熄灭）
    @discardableResult
    func preventDisplaySleep(reason: String, keepLidAwake: Bool = false) -> Bool {
        guard !isActive else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            if keepLidAwake { do { try lidGuard.start() } catch { print("[KeepAwake] 合盖保活授权失败: \(error)") } }
            print("[KeepAwake] 已阻止屏幕睡眠 (reason: \(reason))")
            return true
        } else {
            print("[KeepAwake] 阻止屏幕睡眠失败，IOReturn: \(result)")
            return false
        }
    }

    /// 释放断言，恢复正常睡眠
    @discardableResult
    func allow() -> Bool {
        guard isActive else { return true }
        let sleepResult = IOPMAssertionRelease(assertionID)
        let networkResult = networkAssertionID == 0
            ? kIOReturnSuccess
            : IOPMAssertionRelease(networkAssertionID)
        lidGuard.stop()
        networkLogger.stop()
        assertionID = 0
        networkAssertionID = 0
        if sleepResult == kIOReturnSuccess && networkResult == kIOReturnSuccess {
            print("[KeepAwake] 已恢复系统睡眠")
            isActive = false
            return true
        }
        isActive = false
        print("[KeepAwake] 恢复系统睡眠失败，sleep=\(sleepResult), network=\(networkResult)")
        return false
    }

    deinit {
        allow()  // 确保退出时释放
    }
}
