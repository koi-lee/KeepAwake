# KeepAwake

> 一个轻量的 macOS 菜单栏工具：监控指定 App 是否运行，运行则阻止系统睡眠，退出后恢复。

和 [Amphetamine](https://apps.apple.com/app/amphetamine/id937984704) 的思路类似，但更专注：**只做一件事**——目标在跑就阻止空闲睡眠，目标退了就放开。

非常适合用来「保活」需要联网的长时间运行 App（如 ChatGPT、Claude、下载器、训练脚本）。

---

## ✨ 功能特性

- 🌙 **菜单栏图标**：简洁月亮图标，黑白模板风格，跟随系统主题
- 🔄 **自动检测**：监控 App 启动 / 退出，实时开关睡眠守护
- 🔕 **静默通知**：激活 / 退出时发送系统通知（可关闭）
- ⚙️ **双睡眠模式**：可切换「阻止系统睡眠」或「阻止屏幕睡眠」
- 📝 **图形化管理**：内置应用选择器，搜索勾选即可添加/移除监控目标
- 📦 **DMG 一键打包**：开箱即用的安装包

---

## 🚀 快速开始

### 下载安装

1. 从 [Releases](https://github.com/koi-lee/KeepAwake/releases) 下载最新 `KeepAwake.dmg`
2. 双击挂载，拖拽 `KeepAwake.app` 到 `Applications`
3. 首次打开：系统设置 → 隐私与安全性 → 仍要打开

### 首次打开被 macOS 拦截

KeepAwake 当前使用 Ad-hoc 签名，尚未经过 Apple 公证，因此首次打开时 macOS 可能提示“无法验证开发者”或阻止运行。这不代表应用已经损坏。

推荐按以下顺序处理：

1. 确认已将 `KeepAwake.app` 从 DMG 拖入“应用程序”，不要直接在磁盘镜像中运行。
2. 在 Finder 的“应用程序”中找到 KeepAwake，按住 Control 点击（或右键点击）→ **打开** → 再次选择 **打开**。
3. 如果仍被拦截，进入 **系统设置 → 隐私与安全性**，向下找到 KeepAwake 的拦截提示，点击 **仍要打开**，验证密码或 Touch ID 后再次确认。

如果以上入口没有出现，可在确认安装包来自本仓库官方 Release 后执行：

```bash
xattr -dr com.apple.quarantine /Applications/KeepAwake.app
```

该命令只会移除 KeepAwake 的下载隔离标记，不会修改应用功能。请勿对来源不明的 App 使用此命令。

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

### 图形化方式（推荐）

点击菜单栏图标 → **管理监听应用…**，打开应用选择器：

- 🔍 **搜索**：实时过滤本机应用
- ☑️ **勾选**：勾选即加入监控列表
- 💾 **保存**：自动写入配置并立即生效

### 手动编辑配置

点击菜单栏 → **编辑配置文件…**，会打开 `~/.keepawake.json`：

```json
{
  "watchedApps": [
    { "name": "ChatGPT", "bundleId": "com.openai.chat" },
    { "name": "ChatGPT", "bundleId": "com.openai.codex" },
    { "name": "Claude",   "bundleId": "com.anthropic.claude" },
    { "name": "AnyApp",   "bundleId": null }
  ],
  "checkInterval": 5.0,
  "showNotifications": true
}
```

| 字段 | 说明 |
|------|------|
| `name` | 按名字模糊匹配（不区分大小写），兜底用 |
| `bundleId` | 精确匹配包 ID；设为 `null` 则只靠 `name` 匹配 |
| `checkInterval` | 轮询间隔（秒），默认 5 秒 |
| `showNotifications` | 是否发送激活 / 退出通知 |

> 💡 查某个 App 的 bundleId：
> ```bash
> osascript -e 'id of app "ChatGPT"'
> ```

**⚠️ 注意**：部分机器上 ChatGPT 桌面端的包 ID 是 `com.openai.codex`（而非常见的 `com.openai.chat`）。本工具默认已同时包含两者，并通过「按名字 ChatGPT 模糊匹配」兜底。

改完保存后，**重启 KeepAwake** 生效。

---

## 😴 睡眠模式说明

| 模式 | 阻止内容 | 适用场景 |
|------|---------|---------|
| 系统睡眠（默认） | 防止 Mac 进入空闲睡眠 | 推荐；屏幕仍会按设置熄屏，后台 App 继续运行 |
| 屏幕睡眠 | 屏幕也不会熄灭 | 演示 / 录屏时使用 |

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
- **框架**：AppKit（Cocoa）+ IOKit
- **睡眠控制**：`IOPMAssertionCreateWithName` / `IOPMAssertionRelease`
- **架构**：Universal 2，同时支持 Apple Silicon 与 Intel Mac
- **图标**：独立 Dock ICNS 与菜单栏模板图标，自动适配深色/浅色模式
- **签名**：Ad-hoc（`codesign -s -`），无需开发者账号

## 🔐 隐私说明

KeepAwake 只在本机读取正在运行的应用列表，并把配置保存到 `~/.keepawake.json`。它不联网、不上传应用列表，也不收集使用数据。

---

## ⚠️ 已知限制

1. **合盖仍会睡眠**：macOS 硬规则，任何 App 都无法阻止。要保活请保持开盖或接外接显示器。
2. **系统睡眠 ≠ 屏幕睡眠**：默认模式只阻止系统睡眠，屏幕仍会按系统设置熄屏。切换到「屏幕睡眠」模式可阻止熄屏。
3. 监控基于**应用在前台或后台运行**状态，切换用户时仍生效。

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
