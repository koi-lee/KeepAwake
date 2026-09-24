import AppKit

final class UsageGuideWindowController: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 430),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeepAwake 使用说明"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }
        let title = NSTextField(labelWithString: "KeepAwake 快速上手")
        title.font = .systemFont(ofSize: 24, weight: .semibold)

        let intro = NSTextField(wrappingLabelWithString: "KeepAwake 会根据你的选择阻止 Mac 自动睡眠。你可以临时手动保活，也可以在指定应用运行时自动保活。")
        intro.textColor = .secondaryLabelColor

        let sections: [(String, String)] = [
            ("手动保活", "适合临时下载、会议或演示。选择 30 分钟、1 小时或一直保活。"),
            ("自动监控", "把 ChatGPT、Codex 等应用加入监控列表。应用运行时自动保活，退出后恢复系统睡眠。\n下一步：点击菜单中的“监控列表”，添加要守护的应用。"),
            ("同时使用", "手动保活结束后，只要监控应用仍在运行，KeepAwake 会自动接管并继续保活。"),
            ("睡眠模式", "阻止系统睡眠：屏幕可以熄灭，电脑继续运行。\n阻止屏幕睡眠：屏幕保持常亮。\n合盖保活：合盖后继续运行，需要管理员授权。"),
            ("电源安全", "可以设置低电量停止保活，或只在连接电源时保活，减少电池消耗。")
        ]

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(title)
        stack.addArrangedSubview(intro)

        for (heading, body) in sections {
            let headingLabel = NSTextField(labelWithString: heading)
            headingLabel.font = .systemFont(ofSize: 15, weight: .semibold)
            let bodyLabel = NSTextField(wrappingLabelWithString: body)
            bodyLabel.textColor = .secondaryLabelColor
            let section = NSStackView(views: [headingLabel, bodyLabel])
            section.orientation = .vertical
            section.alignment = .leading
            section.spacing = 4
            stack.addArrangedSubview(section)
        }

        let closeButton = NSButton(title: "知道了，开始使用", target: self, action: #selector(closeGuide))
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\r"
        stack.addArrangedSubview(closeButton)

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    func present() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func closeGuide() {
        window?.close()
    }
}
