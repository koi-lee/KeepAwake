# 合盖授权失败诊断改进

日期：2026-09-25

## 问题证据

用户提供的录屏显示 KeepAwake 弹出“未能启用合盖保活”，原提示只说“管理员授权窗口没有完成”；未解释应输入哪种密码，也未区分取消授权与授权命令执行/握手失败。系统截图显示 Apple M1、macOS Tahoe 26.6.2。

## 改动

- `Sources/KeepAwake/LidSleepGuard.swift`：保留 osascript 退出码，并依据授权命令退出状态提供不同失败说明。
- `Sources/KeepAwake/SleepGuard.swift`：保存最近一次合盖授权错误，供界面显示。
- `Sources/KeepAwake/AppDelegate.swift`：失败弹窗显示具体原因，说明使用 Mac 登录密码。
- `Tests/KeepAwakeTests/KeepAwakeTests.swift`：覆盖授权取消/命令失败与命令正常退出但启动握手未完成两种信息。
- `README.md`：补充首次授权的密码说明及失败状态说明。

## 验证

- `xcodebuild ... build`：通过（macOS 26.5 SDK，Debug，未签名）。
- `swift test`：未运行成功；当前沙箱 SwiftPM manifest 编译被 `sandbox_apply: Operation not permitted` 阻止。
- 实机授权、合盖行为、AppleScript 授权窗具体失败原因：未验证。

## 发布与回滚

未提交、未推送、未打包发布。回滚方式为恢复上述文件的本次改动；发布前应先在目标 Mac 上实测系统授权流程。
