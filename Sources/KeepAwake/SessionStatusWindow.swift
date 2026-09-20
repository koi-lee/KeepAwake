import Cocoa

struct SessionStatusSnapshot {
    let isActive: Bool
    let status: String
    let target: String
    let sleepMode: String
    let power: String
    let startedAt: String
    let remaining: String
    let reason: String

    static let empty = SessionStatusSnapshot(
        isActive: false, status: "未保活", target: "—", sleepMode: "—",
        power: "—", startedAt: "—", remaining: "—", reason: "—"
    )
}

final class SessionStatusWindowController: NSWindowController {
    private let snapshotProvider: () -> SessionStatusSnapshot
    private let stopHandler: () -> Void
    private var labels: [NSTextField] = []
    private var refreshTimer: Timer?
    private weak var stopButton: NSButton?

    init(snapshotProvider: @escaping () -> SessionStatusSnapshot, stopHandler: @escaping () -> Void) {
        self.snapshotProvider = snapshotProvider
        self.stopHandler = stopHandler
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "KeepAwake 会话状态"
        window.center()
        super.init(window: window)
        setupUI()
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        let stack = NSStackView(frame: NSRect(x: 28, y: 76, width: 424, height: 250))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        contentView.addSubview(stack)

        let title = NSTextField(labelWithString: "当前会话")
        title.font = .boldSystemFont(ofSize: 18)
        stack.addArrangedSubview(title)

        for _ in 0..<7 {
            let label = NSTextField(labelWithString: "")
            label.font = .systemFont(ofSize: 13)
            label.lineBreakMode = .byTruncatingTail
            label.translatesAutoresizingMaskIntoConstraints = false
            label.widthAnchor.constraint(equalToConstant: 424).isActive = true
            labels.append(label)
            stack.addArrangedSubview(label)
        }

        let stopButton = NSButton(title: "停止手动保活", target: self, action: #selector(stopSession))
        stopButton.bezelStyle = .rounded
        stopButton.frame = NSRect(x: 28, y: 28, width: 140, height: 32)
        contentView.addSubview(stopButton)
        self.stopButton = stopButton
    }

    private func refresh() {
        let snapshot = snapshotProvider()
        guard labels.count == 7 else { return }
        labels[0].stringValue = "状态：\(snapshot.status)"
        labels[1].stringValue = "目标应用：\(snapshot.target)"
        labels[2].stringValue = "睡眠模式：\(snapshot.sleepMode)"
        labels[3].stringValue = "电源：\(snapshot.power)"
        labels[4].stringValue = "开始时间：\(snapshot.startedAt)"
        labels[5].stringValue = "剩余时间：\(snapshot.remaining)"
        labels[6].stringValue = "原因：\(snapshot.reason)"
        stopButton?.isHidden = !snapshot.isActive
    }

    @objc private func stopSession() {
        stopHandler()
        refresh()
    }
}
