//
//  PowerSafety.swift
//  KeepAwake
//
//  V2 电源安全策略：在激活睡眠断言前检查电池和电源状态。
//

import Foundation

struct PowerStatus: Equatable {
    let isOnBattery: Bool
    let batteryPercent: Int?
    let isKnown: Bool

    static let unknown = PowerStatus(isOnBattery: false, batteryPercent: nil, isKnown: false)

    var summary: String {
        guard isKnown else { return "电源状态未知" }
        let power = isOnBattery ? "电池供电" : "已连接电源"
        if let batteryPercent {
            return "\(power) · 电量 \(batteryPercent)%"
        }
        return power
    }
}

enum PowerSafety {
    static func shouldBlock(
        status: PowerStatus,
        lowBatteryThreshold: Int,
        onlyOnPower: Bool
    ) -> Bool {
        if onlyOnPower && (!status.isKnown || status.isOnBattery) {
            return true
        }
        guard status.isKnown else { return false }

        if lowBatteryThreshold > 0,
           status.isOnBattery,
           let batteryPercent = status.batteryPercent,
           batteryPercent <= lowBatteryThreshold {
            return true
        }
        return false
    }

    static func readStatus() -> PowerStatus {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["-g", "batt"]
        process.standardOutput = output
        process.standardError = Pipe()

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8) else {
                return .unknown
            }
            return parse(text)
        } catch {
            print("[KeepAwake] 读取电源状态失败: \(error)")
            return .unknown
        }
    }

    static func parse(_ text: String) -> PowerStatus {
        let normalized = text.lowercased()
        let isOnBattery: Bool
        if normalized.contains("battery power") {
            isOnBattery = true
        } else if normalized.contains("ac power") {
            isOnBattery = false
        } else {
            return .unknown
        }

        let percent: Int?
        if let range = text.range(of: #"\b\d{1,3}%"#, options: .regularExpression) {
            percent = Int(text[range].dropLast())
        } else {
            percent = nil
        }

        return PowerStatus(isOnBattery: isOnBattery, batteryPercent: percent, isKnown: true)
    }
}
