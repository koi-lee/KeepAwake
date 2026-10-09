# KeepAwake

> 一个轻量的 macOS 菜单栏工具：让应用在线，Mac 不休眠；支持自动监控和手动保活会话。

和 [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) 的思路类似，但更专注：**只做一件事**——目标在跑就阻止空闲睡眠，目标退了就放开。

非常适合用来「保活」需要联网的长时间运行 App（如 ChatGPT、Claude、下载器、训练脚本）。

---

## ✨ 功能特性

- 🌙 **菜单栏图标**：简洁月亮图标，黑白模板风格，跟随系统主题
- 🔄 **自动检测**：监控 App 启动 / 退出，实时开关睡眠守护
- 🔔 **状态反馈与通知**：检查完成会显示即时结果；激活 / 退出时发送系统通知（可关闭），通知权限可从菜单直达系统设置
- ⏱️ **手动保活会话**：支持 30 分钟、默认时长和一直保活，定时结束后自动恢复
- 🔋 **电源安全策略**：支持低电量停止保活，以及仅连接电源时保活
- ⚙️ **三种睡眠模式**：可切换「阻止系统睡眠」「阻止屏幕睡眠」或需要管理员授权的「合盖保活」
- 🌐 **合盖网络保活**：合盖模式同时申请 macOS 网络客户端活跃断言，并记录本地网络状态便于排查中断
- 📝 **图形化管理**：内置应用选择器，搜索勾选即可添加/移除监控目标
- ⚙️ **图形化设置**：可设置开机自动启动、应用检查间隔、默认保活时长和网络日志上限
- 📦 **DMG 一键打包**：开箱即用的安装包

---

## 🚀 快速开始

### 下载安装

1. 从 [最新 GitHub Release](https://github.com/koi-lee/KeepAwake/releases/latest) 下载 `KeepAwake.dmg`，或使用[直接下载链接](https://github.com/koi-lee/KeepAwake/releases/latest/download/KeepAwake.dmg)。截至 2026-10-09，GitHub 独立版最新公开版本是 **2.0.2**，支持 macOS 13+ 与 Apple Silicon / Intel（Universal 2）；App Store 版是 **2.0.3**，两个渠道版本独立。2.0.3（Build 21）的独立 DMG 尚未发布到 GitHub Release。
2. 双击挂载，拖拽 `KeepAwake.app` 到 `Applications`
3. 从菜单栏点击 KeepAwake 图标打开主菜单；首次使用可选“快速上手 / 使用说明…”，通过“管理监听应用…”添加要监控的应用

### 首次打开被 macOS 拦截

公开 Release v2.0.2 的说明注明：DMG 使用 Developer ID 签名，但尚未经过 Apple 公证，因此首次打开时 macOS 可能提示无法验证或阻止运行。此说明只针对当前这版公开 DMG；后续版本的签名和公证状态以各自 Release 说明为准。

如果安装包来自上面的 KeepAwake 官方 GitHub Release，且你确认要继续打开：

1. 在 Finder“应用程序”中找到 KeepAwake，按住 Control 点击（或右键点击）→ **打开**，并在确认提示中再次选择 **打开**。
2. 如果没有这个入口，或仍被拦截，打开 **系统设置 → 隐私与安全性**，在安全性提示中选择 **仍要打开**，按系统提示确认。

不要用命令移除隔离属性或关闭 Gatekeeper 来绕过系统检查。Apple 的[安全打开 Mac App 指引](https://support.apple.com/zh-cn/102445)说明了确认来源可信后允许打开的标准路径；来源不明或无法确认完整性的应用不要继续打开。

### 编译运行

```bash
git clone https://github.com/koi-lee/KeepAwake.git
cd KeepAwake
chmod +x build.sh
./build.sh
open dist/KeepAwake.app
```

### 打包 DMG

```bash
./build.sh --dmg
# 产物: dist/KeepAwake.dmg
```

---

## 📝 配置监控目标

首次启动时，KeepAwake 会默认开启“手动保活 · 一直运行”，让用户可以立即看到保活状态。用户可以在菜单栏的“手动保活会话”中停止；之后应用会保留用户自己的选择，不会在每次启动时强制重新开启。

### 图形化方式（推荐）

点击菜单栏图标 → **管理监听应用…**，打开应用选择器：

- 🔍 **搜索**：实时过滤本机应用
- ☑️ **勾选**：勾选即加入监控列表
- 💾 **保存**：自动写入配置并立即生效

### 检查结果与通知

点击菜单中的 **立即检查 (R)** 后，KeepAwake 会同时更新状态行、显示检查结果提示，并在通知权限已开启时发送系统通知。若通知未显示，打开菜单 → **通知**：

1. 若显示“尚未允许”，点击 **允许 KeepAwake 通知…** 完成首次授权。
2. 若显示“未开启”，点击 **打开系统通知设置…**，在“系统设置 → 通知 → KeepAwake”中打开允许通知。
3. 即使系统通知被关闭，应用内的检查结果提示和状态行仍会显示。

### 手动编辑配置

点击菜单栏 → **编辑配置文件…**，会打开应用配置文件：

`~/Library/Application Support/KeepAwake/config.json`

升级 V1 时，KeepAwake 会尝试把旧的 `~/.keepawake.json` 自动迁移到新位置。

```json
{
  "configVersion": 2,
  "watchedApps": [
    { "name": "ChatGPT", "bundleId": "com.openai.chat" }
  ],
  "checkInterval": 5.0,
  "showNotifications": true,
  "sleepMode": "system",
  "defaultDurationMinutes": 60,
  "lowBatteryThreshold": 20,
  "onlyOnPower": false
}
```

| 字段 | 说明 |
|------|------|
| `name` | 按名字模糊匹配（不区分大小写），兜底用 |
| `bundleId` | 精确匹配包 ID；设为 `null` 则只靠 `name` 匹配 |
| `checkInterval` | 轮询间隔（秒），默认 5 秒 |
| `showNotifications` | 是否发送激活 / 退出通知 |
| `sleepMode` | `system`、`display` 或 `lid`，默认 `system` |
| `defaultDurationMinutes` | 菜单中“默认时长”的分钟数，默认 60 |
| `lowBatteryThreshold` | 电池低于该百分比时停止保活；设为 0 关闭，默认 20 |
| `onlyOnPower` | 是否仅在连接电源时保活，默认 `false` |

> 💡 查某个 App 的 bundleId：
> ```bash
> osascript -e 'id of app "ChatGPT"'
> ```

**⚠️ 注意**：部分机器上 ChatGPT 桌面端的包 ID 是 `com.openai.codex`（而非常见的 `com.openai.chat`）。本工具默认已同时包含两者，并通过「按名字 ChatGPT 模糊匹配」兜底。

改完保存后，**重启 KeepAwake** 生效。

### 图形化设置

点击菜单栏 → **设置…**，可以直接调整：

- 登录后自动启动 KeepAwake
- 应用检查间隔（默认 5 秒）
- 默认手动保活时长（默认 60 分钟）
- 合盖网络诊断日志上限（默认 1 MB，超过后保留最新内容）

监控列表中的目标如果找不到原 bundle ID，状态行会提示“重新识别”；打开“管理监听应用…”后重新勾选当前安装的应用即可更新识别信息。

---

## 😴 睡眠模式说明

| 模式 | 阻止内容 | 适用场景 |
|------|---------|---------|
| 系统睡眠（默认） | 防止 Mac 进入空闲睡眠 | 推荐；屏幕仍会按设置熄屏，后台 App 继续运行 |
| 屏幕睡眠 | 屏幕也不会熄灭 | 演示 / 录屏时使用 |
| 合盖保活 | 阻止空闲睡眠和合盖睡眠，并申请网络客户端活跃断言 | 长时间运行 AI、下载和构建任务；首次启用需要管理员授权，建议连接电源 |

合盖模式的网络诊断仅保存在应用专属的 Application Support 目录，也可通过菜单中的“查看合盖网络诊断日志…”打开。它用于记录网络是否可用、连接接口和 DNS 状态，不会上传日志。

---

## 📁 项目结构

```
KeepAwake/
├── Package.swift              # Swift Package Manager 配置
├── build.sh                   # 编译 & DMG 打包脚本
├── README.md
├── Sources/
│   └── KeepAwake/
│       ├── main.swift         # 应用入口
│       ├── AppDelegate.swift   # 菜单栏 + 状态管理
│       ├── AppConfig.swift     # 配置模型 & 读写
│       ├── Session.swift        # 手动保活会话与到期状态
│       ├── PowerSafety.swift    # 电源状态读取与安全策略数据
│       ├── AppMatcher.swift    # 应用匹配逻辑
│       ├── SleepGuard.swift    # IOKit 睡眠断言
│       ├── AppSelectorWindow.swift  # 应用选择器窗口
│       ├── AppIcon.png         # Dock 图标 (1024×1024)
│       └── MenuBarIcon.png     # 菜单栏模板图标 (64×64)
└── dist/                      # 编译产物（运行 build.sh 后生成）
    ├── KeepAwake.app
    └── KeepAwake.dmg          # 打包后生成
```

---

## 🔧 技术细节

- **编译**：`swiftc -parse-as-library` 手动编译，无 Xcode 项目依赖
- **框架**：AppKit（Cocoa）+ IOKit + Network
- **睡眠控制**：`IOPMAssertionCreateWithName` / `IOPMAssertionRelease`
- **架构**：Universal 2，同时支持 Apple Silicon 与 Intel Mac
- **图标**：独立 Dock ICNS 与菜单栏模板图标，自动适配深色/浅色模式
- **签名**：Ad-hoc（`codesign -s -`），无需开发者账号

## 🔐 隐私说明

KeepAwake 只在本机读取正在运行的应用列表，并把配置保存到应用专属的 Application Support 目录。它不联网、不上传应用列表，也不收集使用数据。

---

## ⚠️ 已知限制

1. **合盖保活需要管理员授权**：首次启用时，在 macOS 系统密码对话框输入这台 Mac 的登录密码并确认；不要输入 Apple 账户密码。授权取消、未出现密码框或系统命令失败时，KeepAwake 会显示失败原因，不会显示为已启用。KeepAwake 会临时调整系统睡眠设置，同时申请网络客户端活跃断言，并在切换模式、目标应用退出或 KeepAwake 退出时恢复原状态。
2. **合盖保活没有固定时长**：只要 KeepAwake 和目标应用仍在运行、授权有效，且 Mac 没有关机、重启或耗尽电量，它会持续工作；长时间使用请连接电源。
3. **系统睡眠 ≠ 屏幕睡眠**：默认模式只阻止系统睡眠，屏幕仍会按系统设置熄屏。切换到「屏幕睡眠」模式可阻止熄屏。
4. 监控基于**应用在前台或后台运行**状态，切换用户时仍生效。
5. **网络保活不等于单条连接永不掉线**：Wi-Fi、代理、运营商或远端服务仍可能中断 ChatGPT/Codex 等应用的长连接；可结合本地诊断日志定位网络状态变化。
6. 手动会话只保存在当前运行进程内，退出 KeepAwake 后会自动释放睡眠断言，不会在下次启动时恢复。
7. 新安装默认不监控任何应用，需要先在“管理监听应用…”中添加目标；升级 V1 配置会保留原有监控列表。

---

## 🔍 搜索关键词

macOS 防睡眠工具、阻止 Mac 睡眠、KeepAwake、菜单栏工具、系统睡眠控制、
应用监控、ChatGPT 保活、Claude 保活、防止 Mac 休眠、macOS sleep preventer、
IOPMAssertion、菜单栏图标、黑白图标、Swift 菜单栏应用、macOS 开发工具、
后台应用守护、防止屏幕熄灭、macOS 电源管理、Amphetamine 替代品、
轻量级睡眠控制、开源 macOS 工具

---

## 📄 开源许可

MIT License

Copyright (c) 2026 Koi Lee

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🙏 致谢

- 灵感来自 [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704)
- 使用 macOS AppKit 与 IOKit 实现菜单栏和睡眠控制

## 项目文档

- [协作规则](AGENTS.md)
- [测试指南](TESTING.md)
- [发布说明](DEPLOYMENT.md)
- [环境变量说明](.env.example)
