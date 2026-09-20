import AppKit

final class SettingsWindowController: NSWindowController {
    private let initialConfig: AppConfig
    private let initialLoginItem: Bool
    private let saveHandler: (AppConfig, Bool) -> Void
    private var intervalField: NSTextField!
    private var durationField: NSTextField!
    private var logLimitField: NSTextField!
    private var loginItemButton: NSButton!

    init(config: AppConfig, loginItemEnabled: Bool, saveHandler: @escaping (AppConfig, Bool) -> Void) {
        self.initialConfig = config
        self.initialLoginItem = loginItemEnabled
        self.saveHandler = saveHandler
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 460, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "KeepAwake 设置"
        window.center()
        super.init(window: window)
        buildUI()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 14; stack.translatesAutoresizingMaskIntoConstraints = false
        loginItemButton = NSButton(checkboxWithTitle: "登录后自动启动 KeepAwake", target: nil, action: nil); loginItemButton.state = initialLoginItem ? .on : .off; stack.addArrangedSubview(loginItemButton); let separator = NSBox(); separator.boxType = .separator; stack.addArrangedSubview(separator)
        intervalField = numberField(value: initialConfig.checkInterval); durationField = numberField(value: Double(initialConfig.defaultDurationMinutes)); logLimitField = numberField(value: Double(AppConfig.logSizeLimitKB(initialConfig.logSizeLimitBytes)))
        addRow("应用检查间隔（秒）", field: intervalField, to: stack); addRow("默认手动保活时长（分钟）", field: durationField, to: stack); addRow("网络日志上限（KB）", field: logLimitField, to: stack)
        let note = NSTextField(wrappingLabelWithString: "日志超过上限时会保留最新内容。设置只影响本机，不会上传数据."); note.textColor = .secondaryLabelColor; stack.addArrangedSubview(note)
        let buttons = NSStackView(); buttons.orientation = .horizontal; buttons.spacing = 8; buttons.addArrangedSubview(NSButton(title: "取消", target: self, action: #selector(cancel))); let save = NSButton(title: "保存", target: self, action: #selector(save)); save.keyEquivalent = "\r"; buttons.addArrangedSubview(save); stack.addArrangedSubview(buttons)
        content.addSubview(stack); NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 24), stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)])
    }
    private func numberField(value: Double) -> NSTextField { let field = NSTextField(string: String(format: "%.0f", value)); field.alignment = .right; field.widthAnchor.constraint(equalToConstant: 90).isActive = true; return field }
    private func addRow(_ title: String, field: NSTextField, to stack: NSStackView) { let row = NSStackView(views: [NSTextField(labelWithString: title), field]); row.orientation = .horizontal; row.spacing = 16; stack.addArrangedSubview(row) }
    @objc private func cancel() { close() }
    @objc private func save() { var config = initialConfig; config.checkInterval = max(1, intervalField.doubleValue); config.defaultDurationMinutes = max(1, durationField.integerValue); config.logSizeLimitBytes = max(64, logLimitField.integerValue) * 1024; saveHandler(config, loginItemButton.state == .on); close() }
}
