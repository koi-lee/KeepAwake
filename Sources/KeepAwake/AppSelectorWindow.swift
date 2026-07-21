//
//  AppSelectorWindow.swift
//  KeepAwake
//
//  应用选择器窗口：搜索、勾选、管理监听列表
//

import Cocoa

struct AppInfo {
    let name: String
    let bundleId: String
    let icon: NSImage?
    let path: String
}

final class AppSelectorWindowController: NSWindowController {
    private var allApps: [AppInfo] = []
    private var filteredApps: [AppInfo] = []
    private var selectedBundleIds: Set<String> = []
    private var onSave: (([WatchedApp]) -> Void)?
    
    private var tableView: NSTableView!
    private var searchField: NSSearchField!
    private var saveButton: NSButton!
    
    convenience init(currentApps: [WatchedApp], onSave: @escaping ([WatchedApp]) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "选择要监听的应用"
        window.center()
        
        self.init(window: window)
        self.onSave = onSave
        
        // 加载当前已选
        self.selectedBundleIds = Set(currentApps.compactMap { $0.bundleId })
        
        setupUI()
        scanApplications()
    }
    
    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        
        // 搜索框
        searchField = NSSearchField(frame: NSRect(x: 20, y: 550, width: 460, height: 30))
        searchField.placeholderString = "搜索应用..."
        searchField.target = self
        searchField.action = #selector(searchChanged(_:))
        contentView.addSubview(searchField)
        
        // 表格
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 70, width: 460, height: 470))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView()
        tableView.allowsMultipleSelection = false
        tableView.headerView = nil
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        
        // 勾选列
        let checkboxColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("checkbox"))
        checkboxColumn.width = 40
        tableView.addTableColumn(checkboxColumn)
        
        // 图标列
        let iconColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("icon"))
        iconColumn.width = 40
        tableView.addTableColumn(iconColumn)
        
        // 名称列
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.width = 380
        tableView.addTableColumn(nameColumn)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // 底部按钮
        let cancelButton = NSButton(frame: NSRect(x: 300, y: 20, width: 80, height: 32))
        cancelButton.title = "取消"
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelClicked)
        contentView.addSubview(cancelButton)
        
        saveButton = NSButton(frame: NSRect(x: 400, y: 20, width: 80, height: 32))
        saveButton.title = "保存"
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveClicked)
        contentView.addSubview(saveButton)
        
        // 提示文字
        let tipLabel = NSTextField(frame: NSRect(x: 20, y: 20, width: 260, height: 32))
        tipLabel.stringValue = "勾选要监听的应用，取消勾选移除"
        tipLabel.isEditable = false
        tipLabel.isBordered = false
        tipLabel.backgroundColor = .clear
        tipLabel.font = NSFont.systemFont(ofSize: 11)
        tipLabel.textColor = .secondaryLabelColor
        contentView.addSubview(tipLabel)
    }
    
    private func scanApplications() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var apps: [AppInfo] = []
            
            let searchPaths = [
                "/Applications",
                "/System/Applications",
                ("~" as NSString).expandingTildeInPath + "/Applications"
            ]
            
            for path in searchPaths {
                guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else { continue }
                
                for item in contents where item.hasSuffix(".app") {
                    let appPath = (path as NSString).appendingPathComponent(item)
                    guard let bundle = Bundle(path: appPath) else { continue }
                    
                    let name = (item as NSString).deletingPathExtension
                    let bundleId = bundle.bundleIdentifier ?? ""
                    guard !bundleId.isEmpty else { continue }
                    let icon = self?.loadAppIcon(path: appPath)
                    
                    // 跳过系统辅助进程
                    if name.lowercased().contains("helper") {
                        continue
                    }
                    
                    apps.append(AppInfo(name: name, bundleId: bundleId, icon: icon, path: appPath))
                }
            }
            
            // 去重（按 bundleId）
            var seen = Set<String>()
            apps = apps.filter { app in
                let key = app.bundleId
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            
            // 排序：已选的在前，然后按名字
            apps.sort { a, b in
                let aSelected = self?.selectedBundleIds.contains(a.bundleId) ?? false
                let bSelected = self?.selectedBundleIds.contains(b.bundleId) ?? false
                if aSelected != bSelected { return aSelected }
                return a.name.localizedCompare(b.name) == .orderedAscending
            }
            
            DispatchQueue.main.async {
                self?.allApps = apps
                self?.filteredApps = apps
                self?.tableView.reloadData()
            }
        }
    }
    
    private func loadAppIcon(path: String) -> NSImage? {
        let infoPath = (path as NSString).appendingPathComponent("Contents/Info.plist")
        guard let info = NSDictionary(contentsOfFile: infoPath) else { return nil }
        
        if let iconFile = info["CFBundleIconFile"] as? String {
            let iconName = (iconFile as NSString).deletingPathExtension
            let iconPath = (path as NSString).appendingPathComponent("Contents/Resources/\(iconName).icns")
            if FileManager.default.fileExists(atPath: iconPath) {
                return NSImage(contentsOfFile: iconPath)
            }
        }
        return nil
    }
    
    @objc private func searchChanged(_ sender: NSSearchField) {
        let query = sender.stringValue.lowercased()
        if query.isEmpty {
            filteredApps = allApps
        } else {
            filteredApps = allApps.filter { $0.name.lowercased().contains(query) }
        }
        tableView.reloadData()
    }
    
    @objc private func cancelClicked() {
        window?.close()
    }
    
    @objc private func saveClicked() {
        let watchedApps = allApps
            .filter { selectedBundleIds.contains($0.bundleId) }
            .map { WatchedApp(name: $0.name, bundleId: $0.bundleId) }
        onSave?(watchedApps)
        window?.close()
    }
    
    @objc private func checkboxClicked(_ sender: NSButton) {
        let row = sender.tag
        guard row < filteredApps.count else { return }
        
        let app = filteredApps[row]
        if sender.state == .on {
            selectedBundleIds.insert(app.bundleId)
        } else {
            selectedBundleIds.remove(app.bundleId)
        }
    }
}

extension AppSelectorWindowController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredApps.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredApps.count else { return nil }
        let app = filteredApps[row]
        
        if tableColumn?.identifier.rawValue == "checkbox" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxClicked(_:)))
            checkbox.tag = row
            checkbox.state = selectedBundleIds.contains(app.bundleId) ? .on : .off
            return checkbox
        }
        
        if tableColumn?.identifier.rawValue == "icon" {
            let imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
            imageView.image = app.icon ?? NSImage(systemSymbolName: "app", accessibilityDescription: nil)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            return imageView
        }
        
        if tableColumn?.identifier.rawValue == "name" {
            let textField = NSTextField(labelWithString: app.name)
            textField.font = NSFont.systemFont(ofSize: 13)
            return textField
        }
        
        return nil
    }
}
