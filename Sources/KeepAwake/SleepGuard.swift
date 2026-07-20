//
//  SleepGuard.swift
//  KeepAwake
//
//  IOKit 电源断言：阻止系统空闲睡眠 / 屏幕睡眠
//

import Foundation
import IOKit.pwr_mgt

/// 睡眠守卫者
/// - 调用 `prevent(reason:)` → 阻止系统空闲睡眠
/// - 调用 `allow()` → 释放断言，恢复正常睡眠行为
final class SleepGuard {
    private var assertionID: IOPMAssertionID = 0
    private(set) var isActive: Bool = false

    /// 阻止系统空闲睡眠（系统不会因空闲而进入睡眠，但合盖仍会睡眠）
    func prevent(reason: String) {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            print("[KeepAwake] 已阻止系统睡眠 (reason: \(reason))")
        } else {
            print("[KeepAwake] 阻止睡眠失败，IOReturn: \(result)")
        }
    }

    /// 阻止屏幕睡眠（屏幕也不会熄灭）
    func preventDisplaySleep(reason: String) {
        guard !isActive else { return }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
            print("[KeepAwake] 已阻止屏幕睡眠 (reason: \(reason))")
        } else {
            print("[KeepAwake] 阻止屏幕睡眠失败，IOReturn: \(result)")
        }
    }

    /// 释放断言，恢复正常睡眠
    func allow() {
        guard isActive else { return }
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            print("[KeepAwake] 已恢复系统睡眠")
            isActive = false
            assertionID = 0
        }
    }

    deinit {
        allow()  // 确保退出时释放
    }
}
