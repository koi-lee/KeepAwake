# KeepAwake 公开安装说明一致性核验（2026-10-09）

## 结果

确认 GitHub README 的“Ad-hoc 签名、未公证”与公开 Release 说明不一致，且原说明建议运行 `xattr -dr com.apple.quarantine` 绕过隔离检查。已修正文案、移除该命令，按当前公开 Release 说明写明签名/公证状态，并采用 Apple 官方支持的 Finder“打开”及系统设置确认路径。没有改动主站。

## 来源与核验

- GitHub `main`：`6a29c4832e0cdec0058399dca307fbc37d7bcafd`；公开原始 README 与本地基线一致。
- 本次文档发布通过 [PR #1](https://github.com/koi-lee/KeepAwake/pull/1) 跟踪。
- GitHub [最新正式 Release](https://github.com/koi-lee/KeepAwake/releases/latest)：v2.0.2（发布于 2026-09-20），唯一资产 `KeepAwake.dmg`，大小 2,986,456 字节。Release 正文称 DMG 使用 Developer ID 签名、未经过 Apple 公证。
- Apple 官方 [App Store 产品页](https://apps.apple.com/cn/app/keepawake/id6799152235?mt=12&uo=4) 的公开 lookup API 回传版本 2.0.3（macOS 13.0+）。Apple 商店版 2.0.3 与 GitHub 独立 DMG 2.0.2 是两个渠道各自的版本，不应混称。
- GitHub API 报告资产 SHA-256：`d3ec567800e7427d4213bfee5f3a39c6ad887bf270e6ed475d161af18f675f56`；下载所得摘要完全一致；`hdiutil verify` 返回磁盘映像校验有效。
- 公开 Release 列表没有 2.0.3。现有发布文档记录 2.0.3（Build 21）为候选，不能将其描述为 GitHub 公开下载版本。
- 本机 `/Applications/KeepAwake.app/Contents/Info.plist` 显示 2.0.0（Build 18）。未停止或覆盖任何运行实例。
- [Apple 安全打开 Mac App](https://support.apple.com/zh-cn/102445)：macOS Gatekeeper 会检查从互联网下载的软件；仅在能确认来源可信时按系统提供的确认流程打开。
- GitHub 官方[Release 链接文档](https://docs.github.com/en/repositories/releasing-projects-on-github/linking-to-releases)支持使用 `/releases/latest` 和 `/releases/latest/download/<asset>` 路径。

## README 变更

- 下载入口改为 GitHub latest Release 页面和 latest asset 直链；注明商店版 2.0.3 与 GitHub 独立版 v2.0.2 的差异，并说明 2.0.3（Build 21）的独立 DMG 尚未在 GitHub 发布。
- 安装后指出菜单栏入口、首次说明和“管理监听应用…”位置。
- v2.0.2 说明明确限定到该公开包，后续包按各自 Release 信息判断。
- 删除移除 quarantine 的 shell 命令，改写为 Finder Control-click → Open，以及系统设置 Privacy & Security 确认路径。

## 文档验证

- GitHub latest Release 页面、latest DMG 直链、Apple 安全打开指引和 GitHub Release 链接文档均返回 HTTP 200。
- `git diff --check` 通过；本次仅修改 Markdown，没有运行应用构建或测试。

## 限制与交付边界

- `hdiutil verify` 和资产摘要验证成功；尝试只读挂载公开 DMG 时系统返回“设备未配置”，`spctl` 的代码签名服务亦返回内部错误。因此没有独立读取该 DMG 内部 App 的 `codesign` 信息或对它作本机 Gatekeeper 结论。签名/公证状态是 GitHub v2.0.2 Release 发布说明中的声明，不冒充本机独立实测。
- 对线上[主站 KeepAwake 介绍页](https://starshoreai.com/keepawake)只读核验发现：GitHub 独立版入口与 2.0.2 标注正确；同页另标“商店版 2.0.2”，与 Apple App Store 2.0.3 不符。已交主协调会话转主站项目处理，本任务未改主站。
- 纯文档改动；没有生成或发布 App 包，也没有安装、退出或重启运行中的 KeepAwake。
