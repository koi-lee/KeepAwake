//
//  AppDelegate.swift
//  KeepAwake
//
//  菜单栏 AppDelegate：图标、菜单、状态轮询、通知
//

import Cocoa
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    // ─── 状态 ───────────────────────────────────────────────
    private var hiddenWindow: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var configMenuItem: NSMenuItem!
    private var sleepModeMenuItem: NSMenuItem!

    private var timer: Timer?
    private var isSleepGuardActive = false
    private var currentMatch: MatchResult = MatchResult(matchedNames: [])

    private var config: AppConfig
    private let sleepGuard = SleepGuard()

    // 睡眠模式：false = 系统睡眠，true = 屏幕睡眠
    private var displaySleepMode = false

    // ─── 初始化 ─────────────────────────────────────────────
    override init() {
        self.config = ConfigLoader.liveConfig
        super.init()
    }

    // ─── App 生命周期 ───────────────────────────────────────
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏 App，但在 Dock 也显示图标（方便刘海屏用户找到）
        NSApp.setActivationPolicy(.regular)
        
        setupStatusItem()
        setupNotifications()
        updateIcon()
        tick()  // 立即检查一次

        // 创建隐藏窗口：保证 App 与 Window Server 保持连接
        hiddenWindow = NSWindow(
            contentRect: NSRect(x: -10000, y: -10000, width: 1, height: 1),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        hiddenWindow.isReleasedWhenClosed = false
        hiddenWindow.orderFront(nil)
        hiddenWindow.level = .floating

        // 定时轮询
        timer = Timer.scheduledTimer(
            withTimeInterval: config.checkInterval,
            repeats: true
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.tick() }
        }

        print("[KeepAwake] 启动完成，监控目标: \(config.watchedApps.map(\.name).joined(separator: ", "))")
    }

    func applicationWillTerminate(_ notification: Notification) {
        sleepGuard.allow()
        print("[KeepAwake] 退出，已恢复系统睡眠")
    }

    // ─── 菜单栏设置 ────────────────────────────────────────
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if #available(macOS 14.0, *) {
            statusItem.isVisible = true
        }
        rebuildMenu()
        // 初始化图标
        updateIcon()
    }

    // ─── 状态轮询 ───────────────────────────────────────────
    private func tick() {
        let result = AppMatcher.match(watchedApps: config.watchedApps)
        currentMatch = result

        if result.hasMatch && !isSleepGuardActive {
            // 目标启动 → 阻止睡眠
            isSleepGuardActive = activateSleepGuard(
                reason: "KeepAwake: \(result.matchedNames.joined(separator: ", "))"
            )
            if isSleepGuardActive {
                sendNotification(
                    title: "KeepAwake 已激活",
                    body: "检测到 \(result.matchedNames.joined(separator: ", "))，已阻止系统睡眠"
                )
            }
        } else if !result.hasMatch && isSleepGuardActive {
            // 目标退出 → 恢复睡眠
            if sleepGuard.allow() {
                isSleepGuardActive = false
                sendNotification(
                    title: "KeepAwake 已休眠",
                    body: "目标应用已关闭，已恢复系统睡眠"
                )
            }
        }

        updateIcon()
        updateStatusText()
    }

    private func activateSleepGuard(reason: String) -> Bool {
        if displaySleepMode {
            return sleepGuard.preventDisplaySleep(reason: reason)
        }
        return sleepGuard.prevent(reason: reason)
    }

    @objc private func checkNow() {
        tick()
    }

    // ─── 通知 ───────────────────────────────────────────────
    private func setupNotifications() {
        // macOS 13+ 用 UNUserNotificationCenter；低版本用 osascript
        if #available(macOS 12.0, *) {
            // 通知授权会在第一次发送时自动弹框
        }
    }

    private func sendNotification(title: String, body: String) {
        guard config.showNotifications else { return }

        if #available(macOS 12.0, *) {
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.sound, .alert]) { granted, _ in
                guard granted else { return }
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let req = UNNotificationRequest(
                    identifier: UUID().uuidString,
                    content: content,
                    trigger: nil
                )
                center.add(req)
            }
        } else {
            // macOS 11 及以下降级用 osascript
            let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
            let safeBody = body.replacingOccurrences(of: "\"", with: "\\\"")
            let script = "display notification \"\(safeBody)\" with title \"\(safeTitle)\" sound name \"Pop\""
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]
            try? task.run()
        }
    }

    // ─── 图标更新 ────────────────────────────────────────────
    private func updateIcon() {
        guard let button = statusItem.button else { return }

        // 使用自定义 PNG 图标（黑白模板样式）
        if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
           let iconImg = NSImage(contentsOfFile: iconPath) {
            iconImg.size = NSSize(width: 18, height: 18)
            iconImg.isTemplate = true
            button.image = iconImg
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyUpOrDown
        } else {
            // 兜底：SF Symbol
            let symbolName = isSleepGuardActive ? "moon.fill" : "moon"
            if let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "KeepAwake") {
                let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                button.image = img.withSymbolConfiguration(cfg)
                button.image?.isTemplate = true
            }
        }

        updateStatusText()
    }

    private func updateStatusText() {
        if isSleepGuardActive {
            let names = currentMatch.matchedNames.isEmpty
                ? "目标运行中"
                : currentMatch.matchedNames.joined(separator: ", ")
            let modeStr = displaySleepMode ? "屏幕睡眠" : "系统睡眠"
            statusMenuItem.title = "✓ 阻止\(modeStr)中 · \(names)"
            statusMenuItem.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        } else {
            statusMenuItem.title = "○ 等待目标应用…"
            statusMenuItem.image = nil
        }

        // 更新睡眠模式菜单项
        if let submenu = sleepModeMenuItem.submenu {
            for (i, item) in submenu.items.enumerated() {
                if i == 0 { item.state = displaySleepMode ? .off : .on }
                if i == 1 { item.state = displaySleepMode ? .on : .off }
            }
        }
    }

    // ─── 菜单构建 ────────────────────────────────────────────
    private func rebuildMenu() {
        let menu = NSMenu()

        // 标题
        let titleItem = NSMenuItem(title: "KeepAwake  ·  应用在线守护", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        // 状态行
        statusMenuItem = NSMenuItem(title: "状态: 初始化…", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())

        // 睡眠模式子菜单
        let sleepSubmenu = NSMenu()
        let systemSleepItem = NSMenuItem(
            title: "阻止系统睡眠（屏幕可熄）",
            action: #selector(setSystemSleepMode),
            keyEquivalent: ""
        )
        systemSleepItem.target = self
        systemSleepItem.state = displaySleepMode ? .off : .on
        let displaySleepItem = NSMenuItem(
            title: "阻止屏幕睡眠（屏幕常亮）",
            action: #selector(setDisplaySleepMode),
            keyEquivalent: ""
        )
        displaySleepItem.target = self
        displaySleepItem.state = displaySleepMode ? .on : .off
        sleepSubmenu.addItem(systemSleepItem)
        sleepSubmenu.addItem(displaySleepItem)
        sleepModeMenuItem = NSMenuItem(title: "睡眠模式", action: nil, keyEquivalent: "")
        sleepModeMenuItem.submenu = sleepSubmenu
        menu.addItem(sleepModeMenuItem)
        menu.addItem(NSMenuItem.separator())

        // 监控列表子菜单
        let watchedSubmenu = NSMenu()
        for app in config.watchedApps {
            let bundleStr = app.bundleId.map { " · \($0)" } ?? " · 按名字匹配"
            let item = NSMenuItem(title: "• \(app.name)\(bundleStr)", action: nil, keyEquivalent: "")
            item.isEnabled = false
            watchedSubmenu.addItem(item)
        }
        watchedSubmenu.addItem(NSMenuItem.separator())
        let addAppItem = NSMenuItem(
            title: "+ 添加/移除应用…",
            action: #selector(openAppSelector),
            keyEquivalent: ""
        )
        addAppItem.target = self
        watchedSubmenu.addItem(addAppItem)
        let watchedItem = NSMenuItem(
            title: "监控列表 (\(config.watchedApps.count))",
            action: nil, keyEquivalent: ""
        )
        watchedItem.submenu = watchedSubmenu
        menu.addItem(watchedItem)
        menu.addItem(NSMenuItem.separator())

        // 操作项
        menu.addItem(NSMenuItem(
            title: "立即检查 (R)",
            action: #selector(checkNow),
            keyEquivalent: "r"
        ))
        menu.items.last?.target = self

        let selectorItem = NSMenuItem(
            title: "管理监听应用…",
            action: #selector(openAppSelector),
            keyEquivalent: ","
        )
        selectorItem.target = self
        menu.addItem(selectorItem)
        
        let editItem = NSMenuItem(
            title: "编辑配置文件（高级）…",
            action: #selector(openConfig),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(
            title: "关于 KeepAwake",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))
        menu.items.last?.target = self

        let quitItem = NSMenuItem(
            title: "退出 KeepAwake (Q)",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // ─── 菜单操作 ────────────────────────────────────────────
    @objc private func setSystemSleepMode() {
        displaySleepMode = false
        rebuildMenu()
        // 如果当前活跃，重新注册断言
        if isSleepGuardActive {
            if sleepGuard.allow() {
                isSleepGuardActive = activateSleepGuard(reason: "KeepAwake (系统睡眠模式)")
            }
        }
        updateStatusText()
    }

    @objc private func setDisplaySleepMode() {
        displaySleepMode = true
        rebuildMenu()
        if isSleepGuardActive {
            if sleepGuard.allow() {
                isSleepGuardActive = activateSleepGuard(reason: "KeepAwake (屏幕睡眠模式)")
            }
        }
        updateStatusText()
    }

    // ─── 应用选择器 ────────────────────────────────────────
    private var appSelectorWindowController: AppSelectorWindowController?
    
    @objc private func openAppSelector() {
        appSelectorWindowController = AppSelectorWindowController(
            currentApps: config.watchedApps
        ) { [weak self] newApps in
            // 保存到配置文件
            let newConfig = AppConfig(
                watchedApps: newApps,
                checkInterval: self?.config.checkInterval ?? 5.0,
                showNotifications: self?.config.showNotifications ?? true
            )
            guard ConfigLoader.saveConfig(newConfig) else {
                let alert = NSAlert()
                alert.messageText = "配置保存失败"
                alert.informativeText = "无法写入 ~/.keepawake.json，请检查文件权限后重试。"
                alert.alertStyle = .warning
                alert.runModal()
                return
            }

            self?.config = newConfig
            self?.rebuildMenu()
            self?.tick()
        }
        appSelectorWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openConfig() {
        ConfigLoader.openInEditor()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "KeepAwake"
        alert.informativeText = """
        版本 1.0.0

        一个轻量的 macOS 菜单栏工具：
        监控指定 App 是否运行，运行则阻止系统睡眠，退出后恢复。

        编译于 \(getCompileDate())
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func getCompileDate() -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: Date())
    }
}
