//
//  AppDelegate.swift
//  KeepAwake
//
//  菜单栏 AppDelegate：图标、菜单、状态轮询、通知
//

import Cocoa
import QuartzCore
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    // ─── 状态 ───────────────────────────────────────────────
    private var hiddenWindow: NSWindow!
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var sourceStatusMenuItem: NSMenuItem!
    private var configMenuItem: NSMenuItem!
    private var sleepModeMenuItem: NSMenuItem!
    private var sessionMenuItem: NSMenuItem!
    private var sessionStatusMenuItem: NSMenuItem!
    private var safetyMenuItem: NSMenuItem!
    private var powerStatusMenuItem: NSMenuItem!
    private var notificationStatusMenuItem: NSMenuItem!
    private var notificationActionMenuItem: NSMenuItem!
    private var sessionStatusWindowController: SessionStatusWindowController?
    private var usageGuideWindowController: UsageGuideWindowController?
    private let shouldShowUsageGuide: Bool

    private var timer: Timer?
    private var isSleepGuardActive = false
    private var currentMatch: MatchResult = MatchResult(matchedNames: [], staleBundleNames: [])
    private var currentPowerStatus = PowerStatus.unknown
    private var manualSession: ManualSession?
    private var activeReason = ""
    private var safetyStopWasNotified = false
    private var powerStatusLastUpdatedAt: Date?
    private var powerStatusRefreshInFlight = false
    private var lidActivationInProgress = false
    private var transientStatus: String?
    private var transientStatusWorkItem: DispatchWorkItem?
    private var feedbackIconWorkItem: DispatchWorkItem?
    private var feedbackPopover: NSPopover?
    private var feedbackPopoverWorkItem: DispatchWorkItem?
    private var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    private var settingsWindowController: SettingsWindowController?
    private let shouldStartDefaultManualSession: Bool

    private var config: AppConfig
    private let sleepGuard = SleepGuard()

    // ─── 初始化 ─────────────────────────────────────────────
    override init() {
        shouldStartDefaultManualSession = !ConfigLoader.hasPersistedConfig
        shouldShowUsageGuide = !ConfigLoader.hasPersistedConfig
        self.config = ConfigLoader.liveConfig
        super.init()
    }

    // ─── App 生命周期 ───────────────────────────────────────
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 菜单栏 App，但在 Dock 也显示图标（方便刘海屏用户找到）
        NSApp.setActivationPolicy(.regular)
        
        setupStatusItem()
        setupNotifications()
        if shouldStartDefaultManualSession {
            ConfigLoader.ensureConfigExists()
            manualSession = ManualSession(startedAt: Date(), kind: .indefinite)
            sendNotification(title: "KeepAwake 手动保活", body: "首次启动已默认开启一直保活，可在菜单中停止")
        }
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
        if shouldShowUsageGuide {
            DispatchQueue.main.async { [weak self] in
                self?.showUsageGuide()
            }
        }
        // 初始化图标
        updateIcon()
    }

    // ─── 状态轮询 ───────────────────────────────────────────
    private func tick() {
        refreshPowerStatusIfNeeded()

        let result = AppMatcher.match(watchedApps: config.watchedApps)
        currentMatch = result

        var manualSessionEnded = false
        if let manualSession, manualSession.isExpired {
            self.manualSession = nil
            manualSessionEnded = true
        }

        let reason = desiredActivationReason()
        let safetyBlocked = reason != nil && isBlockedBySafetyPolicy()

        if let reason, !safetyBlocked {
            if !isSleepGuardActive {
                if config.sleepMode == .lid {
                    beginLidModeActivation(reason: reason)
                } else {
                    activeReason = reason
                    isSleepGuardActive = activateSleepGuard(reason: reason)
                    if isSleepGuardActive {
                        safetyStopWasNotified = false
                        sendNotification(title: "KeepAwake 已激活", body: activationBody())
                    }
                }
            } else {
                activeReason = reason
            }
        } else if isSleepGuardActive {
            if sleepGuard.allow() {
                isSleepGuardActive = false
                activeReason = ""
                if safetyBlocked {
                    notifySafetyStopIfNeeded()
                } else if !manualSessionEnded {
                    sendNotification(title: "KeepAwake 已休眠", body: "目标应用或手动会话已结束，已恢复系统睡眠")
                }
            }
        }

        if manualSessionEnded {
            let body: String
            if safetyBlocked {
                body = "定时会话已结束，当前电源安全策略未继续保活"
            } else if reason != nil {
                body = "定时会话已结束，监控目标仍在运行，继续保活"
            } else {
                body = "定时会话已结束，已恢复正常睡眠行为"
            }
            sendNotification(title: "KeepAwake 定时结束", body: body)
        }

        updateIcon()
        updateStatusText()
        updateSessionMenu()
    }

    private func desiredActivationReason() -> String? {
        if let manualSession {
            return "KeepAwake: \(manualSession.statusText)"
        }
        guard currentMatch.hasMatch else { return nil }
        return "KeepAwake: \(currentMatch.matchedNames.joined(separator: ", "))"
    }

    private func isBlockedBySafetyPolicy() -> Bool {
        PowerSafety.shouldBlock(
            status: currentPowerStatus,
            lowBatteryThreshold: config.lowBatteryThreshold,
            onlyOnPower: config.onlyOnPower
        )
    }

    private func activationBody() -> String {
        let reason = manualSession == nil
            ? "检测到 \(currentMatch.matchedNames.joined(separator: ", "))"
            : "已开始手动保活会话"
        return "\(reason)，\(config.sleepMode.shortTitle)"
    }

    private func notifySafetyStopIfNeeded() {
        guard !safetyStopWasNotified else { return }
        safetyStopWasNotified = true
        let detail: String
        if config.onlyOnPower && !currentPowerStatus.isKnown {
            detail = "无法确认当前是否连接电源"
        } else if config.onlyOnPower && currentPowerStatus.isOnBattery {
            detail = "当前为电池供电"
        } else {
            detail = "电量已低于 \(config.lowBatteryThreshold)%"
        }
        sendNotification(title: "KeepAwake 已停止保活", body: "为保护电池，\(detail)")
    }

    private func refreshPowerStatusIfNeeded(force: Bool = false) {
        guard !powerStatusRefreshInFlight else { return }
        if !force,
           let lastUpdated = powerStatusLastUpdatedAt,
           Date().timeIntervalSince(lastUpdated) < 30 {
            return
        }

        powerStatusRefreshInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let status = PowerSafety.readStatus()
            DispatchQueue.main.async {
                guard let self else { return }
                self.currentPowerStatus = status
                self.powerStatusLastUpdatedAt = Date()
                self.powerStatusRefreshInFlight = false
                self.tick()
            }
        }
    }

    private func beginLidModeActivation(reason: String) {
        guard !lidActivationInProgress else { return }
        lidActivationInProgress = true
        transientStatus = "正在请求合盖保活授权…"
        NSApp.activate(ignoringOtherApps: true)
        updateStatusText()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let activated = self?.sleepGuard.prevent(reason: reason, keepLidAwake: true) ?? false
            DispatchQueue.main.async {
                guard let self else { return }
                self.lidActivationInProgress = false
                var shouldKeepActive = activated &&
                    self.config.sleepMode == .lid &&
                    self.desiredActivationReason() != nil &&
                    !self.isBlockedBySafetyPolicy()
                if activated && !shouldKeepActive {
                    _ = self.sleepGuard.allow()
                    shouldKeepActive = false
                }
                self.isSleepGuardActive = shouldKeepActive
                if shouldKeepActive {
                    self.activeReason = reason
                    self.safetyStopWasNotified = false
                    self.sendNotification(title: "KeepAwake 已激活", body: self.activationBody())
                } else if !activated {
                    self.handleLidModeActivationFailure()
                }
                self.updateIcon()
                self.updateStatusText()
                self.updateSessionMenu()
            }
        }
    }

    private func activateSleepGuard(reason: String) -> Bool {
        switch config.sleepMode {
        case .system:
            return sleepGuard.prevent(reason: reason)
        case .display:
            return sleepGuard.preventDisplaySleep(reason: reason)
        case .lid:
            return sleepGuard.prevent(reason: reason, keepLidAwake: true)
        }
    }

    @objc private func checkNow() {
        refreshPowerStatusIfNeeded(force: true)
        tick()
        let target = currentMatch.hasMatch
            ? currentMatch.matchedNames.joined(separator: ", ")
            : "无目标应用运行"
        let result = "已检查 · \(target) · \(currentPowerStatus.summary)"
        showTransientStatus(result)
        showCheckFeedback()
        showFeedbackPopover(
            title: "立即检查完成",
            body: "\(result)\n\(notificationStatusSummary)"
        )
        sendNotification(title: "KeepAwake 检查完成", body: result)
    }

    private func showTransientStatus(_ message: String) {
        transientStatusWorkItem?.cancel()
        transientStatus = message
        updateStatusText()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.transientStatus = nil
            self.updateStatusText()
        }
        transientStatusWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func showCheckFeedback() {
        guard let button = statusItem.button else { return }
        feedbackIconWorkItem?.cancel()

        if let image = NSImage(
            systemSymbolName: "checkmark.circle.fill",
            accessibilityDescription: "检查完成"
        )?.withSymbolConfiguration(.init(pointSize: 16, weight: .semibold)) {
            image.isTemplate = true
            button.image = image
        }
        button.toolTip = "KeepAwake：检查完成"

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.buttonRestoreAfterCheckFeedback()
        }
        feedbackIconWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }

    private func buttonRestoreAfterCheckFeedback() {
        statusItem.button?.toolTip = nil
        updateIcon()
    }

    private func showFeedbackPopover(title: String, body: String) {
        guard let button = statusItem.button else { return }
        feedbackPopoverWorkItem?.cancel()
        feedbackPopover?.performClose(nil)

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .boldSystemFont(ofSize: 13)
        titleLabel.lineBreakMode = .byTruncatingTail

        let bodyLabel = NSTextField(wrappingLabelWithString: body)
        bodyLabel.font = .systemFont(ofSize: 12)
        bodyLabel.textColor = .secondaryLabelColor
        bodyLabel.maximumNumberOfLines = 3

        let stack = NSStackView(views: [titleLabel, bodyLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 300, height: 76))
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -12)
        ])

        let viewController = NSViewController()
        viewController.view = container
        popover.contentViewController = viewController
        popover.contentSize = NSSize(width: 300, height: 76)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        feedbackPopover = popover

        let workItem = DispatchWorkItem { [weak self, weak popover] in
            popover?.performClose(nil)
            if self?.feedbackPopover === popover {
                self?.feedbackPopover = nil
            }
        }
        feedbackPopoverWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6, execute: workItem)
    }

    // ─── 通知 ───────────────────────────────────────────────
    private func setupNotifications() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorization = settings.authorizationStatus
                self.updateNotificationMenu()
                guard self.config.showNotifications,
                      settings.authorizationStatus == .notDetermined else { return }
                self.requestNotificationPermission(center: center)
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        guard config.showNotifications else { return }

        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                self.notificationAuthorization = settings.authorizationStatus
                self.updateNotificationMenu()

                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    self.addNotification(title: title, body: body, using: center)
                case .notDetermined:
                    self.requestNotificationPermission(center: center, thenSend: (title, body))
                case .denied:
                    self.showNotificationDisabledFeedback()
                @unknown default:
                    self.showNotificationDisabledFeedback()
                }
            }
        }
    }

    private func refreshNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationAuthorization = settings.authorizationStatus
                self?.updateNotificationMenu()
            }
        }
    }

    private func addNotification(
        title: String,
        body: String,
        using center: UNUserNotificationCenter
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request)
    }

    private func requestNotificationPermission(
        center: UNUserNotificationCenter,
        thenSend notification: (title: String, body: String)? = nil
    ) {
        center.requestAuthorization(options: [.sound, .alert]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.refreshNotificationAuthorization()
                if granted, let notification {
                    self.addNotification(
                        title: notification.title,
                        body: notification.body,
                        using: center
                    )
                } else if granted {
                    self.showTransientStatus("KeepAwake 通知已开启")
                } else if !granted {
                    self.showNotificationDisabledFeedback()
                }
            }
        }
    }

    private var notificationStatusSummary: String {
        guard config.showNotifications else { return "应用通知已在配置中关闭" }
        switch notificationAuthorization {
        case .authorized, .provisional:
            return "系统通知：已开启"
        case .notDetermined:
            return "系统通知：尚未允许"
        case .denied:
            return "系统通知：未开启，请打开通知设置"
        @unknown default:
            return "系统通知：状态未知"
        }
    }

    private func updateNotificationMenu() {
        guard notificationStatusMenuItem != nil else { return }
        notificationStatusMenuItem.title = notificationStatusSummary
        if !config.showNotifications {
            notificationActionMenuItem.title = "通知已在配置中关闭"
            notificationActionMenuItem.isEnabled = false
        } else if notificationAuthorization == .notDetermined {
            notificationActionMenuItem.title = "允许 KeepAwake 通知…"
            notificationActionMenuItem.isEnabled = true
        } else {
            notificationActionMenuItem.title = "打开系统通知设置…"
            notificationActionMenuItem.isEnabled = true
        }
    }

    private func showNotificationDisabledFeedback() {
        showTransientStatus("通知未开启，请打开通知设置")
        showFeedbackPopover(
            title: "通知未开启",
            body: "检查结果仍已完成。请在“通知”菜单中打开系统设置，允许 KeepAwake 发送通知。"
        )
    }

    @objc private func manageNotifications() {
        guard config.showNotifications else {
            showFeedbackPopover(title: "通知已关闭", body: "请在高级配置中将 showNotifications 改为 true。")
            return
        }

        if notificationAuthorization == .notDetermined {
            requestNotificationPermission(center: .current())
        } else {
            openNotificationSettings()
        }
    }

    @objc private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            showFeedbackPopover(title: "无法打开通知设置", body: "请手动打开：系统设置 → 通知 → KeepAwake")
            return
        }
        NSWorkspace.shared.open(url)
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
        let baseTitle: String
        if lidActivationInProgress {
            baseTitle = "○ 正在请求合盖保活授权…"
            statusMenuItem.image = NSImage(systemSymbolName: "lock.open", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        } else if isSleepGuardActive {
            baseTitle = "✓ \(config.sleepMode.title)"
            statusMenuItem.image = NSImage(systemSymbolName: "checkmark.circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        } else if let manualSession {
            baseTitle = manualSession.isExpired ? "○ 手动会话即将结束" : "○ 手动保活已设置 · \(manualSession.statusText) · 等待电源安全条件"
            statusMenuItem.image = NSImage(systemSymbolName: "pause.circle", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 12, weight: .regular))
        } else {
            let targetText = config.watchedApps.isEmpty ? "请添加目标应用" : "等待目标应用…"
            baseTitle = "○ \(targetText)"
            statusMenuItem.image = nil
        }
        statusMenuItem.title = transientStatus.map { "\(baseTitle) · \($0)" } ?? baseTitle
        sourceStatusMenuItem?.title = sourceStatusText()

        // 更新睡眠模式菜单项
        if let submenu = sleepModeMenuItem.submenu {
            for (index, item) in submenu.items.enumerated() {
                item.state = (index == 0 && config.sleepMode == .system) ||
                    (index == 1 && config.sleepMode == .display) ||
                    (index == 2 && config.sleepMode == .lid) ? .on : .off
            }
        }

        powerStatusMenuItem?.title = "电源状态：\(currentPowerStatus.summary)"
        updateNotificationMenu()
        if let safetyItems = safetyMenuItem?.submenu?.items {
            for item in safetyItems {
                if item.tag == 0, item.title == "不设置低电量保护" {
                    item.state = config.lowBatteryThreshold == 0 ? .on : .off
                } else if item.tag > 0 {
                    item.state = item.tag == config.lowBatteryThreshold ? .on : .off
                }
                if item.title == "仅连接电源时保活" {
                    item.state = config.onlyOnPower ? .on : .off
                }
            }
        }
    }

    private func sourceStatusText() -> String {
        if !currentMatch.staleBundleNames.isEmpty {
            return "监控目标未找到：\(currentMatch.staleBundleNames.joined(separator: "、")) · 打开监控列表重新识别"
        }
        if let manualSession {
            let duration = manualSession.endsAt.map { ManualSession.durationText(until: $0) } ?? "一直运行"
            if currentMatch.hasMatch {
                return "手动保活剩余 \(duration)；结束后由 \(currentMatch.matchedNames.joined(separator: "、")) 自动保活"
            }
            return "当前由手动保活提供 · \(duration)"
        }
        if currentMatch.hasMatch {
            return "当前由 \(currentMatch.matchedNames.joined(separator: "、")) 自动保活"
        }
        return "保活来源：未启动 · 等待监控应用或手动操作"
    }

    private func updateSessionMenu() {
        guard let submenu = sessionMenuItem?.submenu else { return }
        for item in submenu.items {
            item.state = .off
        }
        sessionStatusMenuItem?.title = sessionSourceSummary()
        sessionStatusMenuItem?.isHidden = manualSession == nil && !currentMatch.hasMatch
        if let stopItem = submenu.items.first(where: { $0.action == #selector(stopManualSession) }) {
            stopItem.isEnabled = manualSession != nil
            stopItem.title = manualSession == nil ? "停止本次手动保活（未开启）" : "停止本次手动保活"
        }
    }

    private func sessionSourceSummary() -> String {
        var sources: [String] = []
        if let manualSession {
            let duration = manualSession.endsAt.map { ManualSession.durationText(until: $0) } ?? "一直运行"
            sources.append("手动保活剩余 \(duration)")
        }
        if currentMatch.hasMatch {
            sources.append("自动保活：\(currentMatch.matchedNames.joined(separator: "、"))")
        }
        return sources.isEmpty ? "当前未保活 · 等待监控应用或手动操作" : "当前：\(sources.joined(separator: "；"))"
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
        powerStatusMenuItem = NSMenuItem(title: "电源状态：读取中…", action: nil, keyEquivalent: "")
        powerStatusMenuItem.isEnabled = false
        menu.addItem(powerStatusMenuItem)
        sourceStatusMenuItem = NSMenuItem(title: "保活来源：读取中…", action: nil, keyEquivalent: "")
        sourceStatusMenuItem.isEnabled = false
        menu.addItem(sourceStatusMenuItem)
        menu.addItem(NSMenuItem.separator())

        // 手动保活会话
        let sessionSubmenu = NSMenu()
        sessionStatusMenuItem = NSMenuItem(title: "当前未保活 · 等待监控应用或手动操作", action: nil, keyEquivalent: "")
        sessionStatusMenuItem.isEnabled = false
        sessionSubmenu.addItem(sessionStatusMenuItem)
        sessionSubmenu.addItem(NSMenuItem.separator())
        let thirtyMinuteItem = NSMenuItem(
            title: "保活 30 分钟",
            action: #selector(startThirtyMinuteSession),
            keyEquivalent: ""
        )
        thirtyMinuteItem.target = self
        sessionSubmenu.addItem(thirtyMinuteItem)
        let hourItem = NSMenuItem(
            title: "保活 \(ManualSession.durationText(minutes: config.defaultDurationMinutes))",
            action: #selector(startDefaultSession),
            keyEquivalent: ""
        )
        hourItem.target = self
        sessionSubmenu.addItem(hourItem)
        let indefiniteItem = NSMenuItem(
            title: "一直保活",
            action: #selector(startIndefiniteSession),
            keyEquivalent: ""
        )
        indefiniteItem.target = self
        sessionSubmenu.addItem(indefiniteItem)
        sessionSubmenu.addItem(NSMenuItem.separator())
        let stopItem = NSMenuItem(
            title: "停止本次手动保活（未开启）",
            action: #selector(stopManualSession),
            keyEquivalent: ""
        )
        stopItem.target = self
        sessionSubmenu.addItem(stopItem)
        sessionMenuItem = NSMenuItem(title: "手动保活会话", action: nil, keyEquivalent: "")
        sessionMenuItem.submenu = sessionSubmenu
        menu.addItem(sessionMenuItem)

        // 睡眠模式子菜单
        let sleepSubmenu = NSMenu()
        let systemSleepItem = NSMenuItem(
            title: SleepMode.system.title,
            action: #selector(setSystemSleepMode),
            keyEquivalent: ""
        )
        systemSleepItem.target = self
        systemSleepItem.state = config.sleepMode == .system ? .on : .off
        let displaySleepItem = NSMenuItem(
            title: SleepMode.display.title,
            action: #selector(setDisplaySleepMode),
            keyEquivalent: ""
        )
        displaySleepItem.target = self
        displaySleepItem.state = config.sleepMode == .display ? .on : .off
        let lidSleepItem = NSMenuItem(
            title: SleepMode.lid.title,
            action: #selector(setLidSleepMode),
            keyEquivalent: ""
        )
        lidSleepItem.target = self
        lidSleepItem.state = config.sleepMode == .lid ? .on : .off
        sleepSubmenu.addItem(systemSleepItem)
        sleepSubmenu.addItem(displaySleepItem)
        sleepSubmenu.addItem(lidSleepItem)
        sleepModeMenuItem = NSMenuItem(title: "睡眠模式", action: nil, keyEquivalent: "")
        sleepModeMenuItem.submenu = sleepSubmenu
        menu.addItem(sleepModeMenuItem)

        // 电源安全策略
        let safetySubmenu = NSMenu()
        let batteryOffItem = NSMenuItem(
            title: "不设置低电量保护",
            action: #selector(setBatteryProtectionOff),
            keyEquivalent: ""
        )
        batteryOffItem.target = self
        safetySubmenu.addItem(batteryOffItem)
        for threshold in [10, 20, 30] {
            let item = NSMenuItem(
                title: "电量低于 \(threshold)% 时停止",
                action: #selector(setBatteryProtection(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.tag = threshold
            safetySubmenu.addItem(item)
        }
        safetySubmenu.addItem(NSMenuItem.separator())
        let powerOnlyItem = NSMenuItem(
            title: "仅连接电源时保活",
            action: #selector(toggleOnlyOnPower),
            keyEquivalent: ""
        )
        powerOnlyItem.target = self
        safetySubmenu.addItem(powerOnlyItem)
        safetyMenuItem = NSMenuItem(title: "电源安全", action: nil, keyEquivalent: "")
        safetyMenuItem.submenu = safetySubmenu
        menu.addItem(safetyMenuItem)

        // 通知状态与系统设置入口
        let notificationSubmenu = NSMenu()
        notificationStatusMenuItem = NSMenuItem(title: "通知：读取中…", action: nil, keyEquivalent: "")
        notificationStatusMenuItem.isEnabled = false
        notificationSubmenu.addItem(notificationStatusMenuItem)
        let notificationActionItem = NSMenuItem(
            title: "打开系统通知设置…",
            action: #selector(manageNotifications),
            keyEquivalent: ""
        )
        notificationActionItem.target = self
        notificationActionMenuItem = notificationActionItem
        notificationSubmenu.addItem(notificationActionItem)
        let notificationMenuItem = NSMenuItem(title: "通知", action: nil, keyEquivalent: "")
        notificationMenuItem.submenu = notificationSubmenu
        menu.addItem(notificationMenuItem)
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

        let sessionStatusItem = NSMenuItem(
            title: "查看会话状态…",
            action: #selector(showSessionStatus),
            keyEquivalent: ""
        )
        sessionStatusItem.target = self
        menu.addItem(sessionStatusItem)

        let selectorItem = NSMenuItem(
            title: "管理监听应用…",
            action: #selector(openAppSelector),
            keyEquivalent: ","
        )
        selectorItem.target = self
        menu.addItem(selectorItem)

        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        let editItem = NSMenuItem(
            title: "编辑配置文件（高级）…",
            action: #selector(openConfig),
            keyEquivalent: ""
        )
        editItem.target = self
        menu.addItem(editItem)

        let networkLogItem = NSMenuItem(
            title: "查看合盖网络诊断日志…",
            action: #selector(openNetworkLog),
            keyEquivalent: ""
        )
        networkLogItem.target = self
        menu.addItem(networkLogItem)

        menu.addItem(NSMenuItem.separator())
        let guideItem = NSMenuItem(
            title: "快速上手 / 使用说明…",
            action: #selector(showUsageGuide),
            keyEquivalent: ""
        )
        guideItem.target = self
        menu.addItem(guideItem)
        menu.addItem(NSMenuItem(
            title: "关于 KeepAwake",
            action: #selector(showAbout),
            keyEquivalent: ""
        ))
        menu.items.last?.target = self

        let quitItem = NSMenuItem(
            title: "Quit KeepAwake",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // ─── 菜单操作 ────────────────────────────────────────────
    @objc private func startThirtyMinuteSession() {
        startManualSession(minutes: 30)
    }

    @objc private func startDefaultSession() {
        startManualSession(minutes: config.defaultDurationMinutes)
    }

    @objc private func startIndefiniteSession() {
        manualSession = ManualSession(startedAt: Date(), kind: .indefinite)
        safetyStopWasNotified = false
        sendNotification(title: "KeepAwake 手动保活", body: "已开始一直运行的手动会话")
        tick()
    }

    private func startManualSession(minutes: Int) {
        let safeMinutes = max(1, minutes)
        manualSession = ManualSession(
            startedAt: Date(),
            kind: .timed(endsAt: Date().addingTimeInterval(TimeInterval(safeMinutes * 60)))
        )
        safetyStopWasNotified = false
        sendNotification(title: "KeepAwake 手动保活", body: "已开始 \(safeMinutes) 分钟会话")
        tick()
    }

    @objc private func stopManualSession() {
        guard manualSession != nil else { return }
        manualSession = nil
        tick()
    }

    @objc private func showSessionStatus() {
        if sessionStatusWindowController == nil {
            sessionStatusWindowController = SessionStatusWindowController(
                snapshotProvider: { [weak self] in self?.sessionStatusSnapshot() ?? .empty },
                stopHandler: { [weak self] in self?.stopManualSession() }
            )
        }
        sessionStatusWindowController?.showWindow(nil)
        sessionStatusWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func sessionStatusSnapshot() -> SessionStatusSnapshot {
        let target = currentMatch.hasMatch
            ? currentMatch.matchedNames.joined(separator: ", ")
            : (config.watchedApps.isEmpty ? "未配置" : "等待目标应用")
        let session = manualSession
        let startedAt = session.map { Self.statusDateFormatter.string(from: $0.startedAt) } ?? "—"
        let remaining = session?.endsAt.map { ManualSession.durationText(until: $0) } ?? (session == nil ? "—" : "一直运行")
        let reason = isSleepGuardActive
            ? activeReason.replacingOccurrences(of: "KeepAwake: ", with: "")
            : (isBlockedBySafetyPolicy() ? "电源安全策略暂未允许保活" : "等待目标应用或手动会话")
        return SessionStatusSnapshot(
            isActive: session != nil,
            status: isSleepGuardActive ? "保活中" : "未保活",
            target: target,
            sleepMode: config.sleepMode.title,
            power: currentPowerStatus.summary,
            startedAt: startedAt,
            remaining: remaining,
            reason: reason
        )
    }

    private static let statusDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()

    @objc private func setBatteryProtectionOff() {
        config.lowBatteryThreshold = 0
        _ = ConfigLoader.saveConfig(config)
        updateStatusText()
        tick()
    }

    @objc private func setBatteryProtection(_ sender: NSMenuItem) {
        config.lowBatteryThreshold = sender.tag
        _ = ConfigLoader.saveConfig(config)
        updateStatusText()
        tick()
    }

    @objc private func toggleOnlyOnPower() {
        config.onlyOnPower.toggle()
        _ = ConfigLoader.saveConfig(config)
        updateStatusText()
        tick()
    }

    @objc private func setSystemSleepMode() {
        setSleepMode(.system)
    }

    @objc private func setDisplaySleepMode() {
        setSleepMode(.display)
    }

    @objc private func setLidSleepMode() {
        setSleepMode(.lid)
    }

    private func setSleepMode(_ newMode: SleepMode) {
        guard config.sleepMode != newMode else { return }
        let previousMode = config.sleepMode
        config.sleepMode = newMode
        _ = ConfigLoader.saveConfig(config)
        rebuildMenu()

        if isSleepGuardActive {
            guard sleepGuard.allow() else {
                config.sleepMode = previousMode
                _ = ConfigLoader.saveConfig(config)
                rebuildMenu()
                showTransientStatus("切换睡眠模式失败，已保持原模式")
                return
            }
            isSleepGuardActive = false
            activeReason = ""
        }

        if let desiredReason = desiredActivationReason(), !isBlockedBySafetyPolicy() {
            if config.sleepMode == .lid {
                beginLidModeActivation(reason: desiredReason)
            } else {
                activeReason = desiredReason
                isSleepGuardActive = activateSleepGuard(reason: desiredReason)
                if isSleepGuardActive {
                    sendNotification(title: "KeepAwake 已激活", body: activationBody())
                }
            }
        }
        updateStatusText()
        animateModeChangeFeedback()
    }

    private func animateModeChangeFeedback() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let button = statusItem.button else { return }
        button.alphaValue = 0.55
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            button.animator().alphaValue = 1
        }
    }

    private func handleLidModeActivationFailure() {
        config.sleepMode = .system
        _ = ConfigLoader.saveConfig(config)
        rebuildMenu()
        updateStatusText()
        let alert = NSAlert()
        alert.messageText = "未能启用合盖保活"
        alert.informativeText = "管理员授权窗口没有完成。请点击“重新授权”，KeepAwake 会再次将授权请求置于前台；也可以取消并继续使用“阻止系统睡眠”模式。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "重新授权")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            config.sleepMode = .lid
            _ = ConfigLoader.saveConfig(config)
            rebuildMenu()
            if let desiredReason = desiredActivationReason() {
                beginLidModeActivation(reason: desiredReason)
            }
        }
    }

    // ─── 应用选择器 ────────────────────────────────────────
    private var appSelectorWindowController: AppSelectorWindowController?
    
    @objc private func openAppSelector() {
        appSelectorWindowController = AppSelectorWindowController(
            currentApps: config.watchedApps
        ) { [weak self] newApps in
            // 保存到配置文件
            let newConfig = AppConfig(
                configVersion: self?.config.configVersion ?? AppConfig.currentVersion,
                watchedApps: newApps,
                checkInterval: self?.config.checkInterval ?? 5.0,
                showNotifications: self?.config.showNotifications ?? true,
                sleepMode: self?.config.sleepMode ?? .system,
                defaultDurationMinutes: self?.config.defaultDurationMinutes ?? 60,
                lowBatteryThreshold: self?.config.lowBatteryThreshold ?? 20,
                onlyOnPower: self?.config.onlyOnPower ?? false
            )
            guard ConfigLoader.saveConfig(newConfig) else {
                let alert = NSAlert()
                alert.messageText = "配置保存失败"
                alert.informativeText = "无法写入应用配置目录，请检查文件权限后重试。"
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

    @objc private func openSettings() {
        settingsWindowController = SettingsWindowController(config: config, loginItemEnabled: LoginItemManager.isEnabled) { [weak self] newConfig, loginEnabled in
            guard let self else { return }
            guard LoginItemManager.setEnabled(loginEnabled) else { self.showTransientStatus("开机启动设置失败"); return }
            guard ConfigLoader.saveConfig(newConfig) else { self.showTransientStatus("设置保存失败"); return }
            self.config = newConfig
            self.timer?.invalidate()
            self.timer = Timer.scheduledTimer(withTimeInterval: newConfig.checkInterval, repeats: true) { [weak self] _ in self?.tick() }
            self.rebuildMenu()
            self.tick()
            self.showTransientStatus("设置已保存")
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openNetworkLog() {
        NetworkPathLogger.ensureLogExists()
        NSWorkspace.shared.open(NetworkPathLogger.logURL)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "KeepAwake"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let versionText = build.map { "\(version) (构建 \($0))" } ?? version
        alert.informativeText = """
        版本 \(versionText)

        一个轻量的 macOS 菜单栏工具：
        监控指定 App 是否运行，运行则阻止系统睡眠，退出后恢复。

        编译于 \(getCompileDate())
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好的")
        alert.runModal()
    }

    @objc private func showUsageGuide() {
        if usageGuideWindowController == nil {
            usageGuideWindowController = UsageGuideWindowController()
        }
        usageGuideWindowController?.present()
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

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
