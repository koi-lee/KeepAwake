//
//  Session.swift
//  KeepAwake
//
//  V2 会话模型：把“为什么保持唤醒”和“什么时候结束”从菜单逻辑中分离出来。
//

import Foundation

enum ManualSessionKind: Equatable {
    case timed(endsAt: Date)
    case indefinite
}

struct ManualSession: Equatable {
    let startedAt: Date
    let kind: ManualSessionKind

    var endsAt: Date? {
        if case let .timed(date) = kind { return date }
        return nil
    }

    var isExpired: Bool {
        isExpired(at: Date())
    }

    func isExpired(at date: Date) -> Bool {
        guard let endsAt else { return false }
        return date >= endsAt
    }

    var statusText: String {
        switch kind {
        case .indefinite:
            return "手动保活 · 一直运行"
        case let .timed(endsAt):
            return "手动保活 · \(Self.durationText(until: endsAt))"
        }
    }

    static func durationText(until date: Date, now: Date = Date()) -> String {
        let remaining = max(0, Int(date.timeIntervalSince(now).rounded(.up)))
        let minutes = remaining / 60
        let seconds = remaining % 60

        return durationText(minutes: minutes, extraSeconds: seconds)
    }

    static func durationText(minutes: Int) -> String {
        durationText(minutes: max(0, minutes), extraSeconds: 0)
    }

    private static func durationText(minutes: Int, extraSeconds: Int) -> String {
        if minutes >= 60 {
            let hours = minutes / 60
            let extraMinutes = minutes % 60
            return extraMinutes == 0 ? "\(hours) 小时" : "\(hours) 小时 \(extraMinutes) 分钟"
        }
        if minutes > 0 {
            return extraSeconds == 0 ? "\(minutes) 分钟" : "\(minutes) 分钟 \(extraSeconds) 秒"
        }
        return "\(extraSeconds) 秒"
    }
}
