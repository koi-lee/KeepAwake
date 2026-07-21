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
    @discardableResult
    func prevent(reason: String) -> Bool {
        guard !isActive else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
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
    func preventDisplaySleep(reason: String) -> Bool {
        guard !isActive else { return true }
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason as CFString,
            &assertionID
        )
        if result == kIOReturnSuccess {
            isActive = true
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
        let result = IOPMAssertionRelease(assertionID)
        if result == kIOReturnSuccess {
            print("[KeepAwake] 已恢复系统睡眠")
            isActive = false
            assertionID = 0
            return true
        }
        print("[KeepAwake] 恢复系统睡眠失败，IOReturn: \(result)")
        return false
    }

    deinit {
        allow()  // 确保退出时释放
    }
}
