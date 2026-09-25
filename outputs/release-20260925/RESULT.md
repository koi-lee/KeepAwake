# KeepAwake 2.0.3 Build 21 发布记录

日期：2026-09-25

## 已完成

- 将 App Store 版本提升为 `2.0.3`、构建号提升为 `21`。App Store Connect 拒绝 `2.0.1 (20)`：该版本线已关闭、已批准版本为 2.0.2，且构建号 20 已被使用。
- `swift test`：13 项通过，0 项失败。
- Xcode Release Archive：成功，归档版本 `2.0.3 (21)`，使用 `Apple Distribution: ZEAN LI (4BHPD976HX)`。
- Xcode 导出上传：返回 `Upload succeeded`，Build 21 已交给 App Store Connect 处理。

## 尚未完成

- 本次操作后尚未再次读取 App Store Connect 页面，因此 Apple 的处理结果、Build 21 是否可选，以及 2.0.3 页面审核资料是否完整均未确认；也未提交审核。
- 2.0.3 Developer ID DMG 尚未生成。正式签名和隔离诊断（包括 `--timestamp=none`）均在 `codesign` 调用 `Developer ID Application: ZEAN LI (4BHPD976HX)` 私钥时持续等待后被中断；因此证据指向钥匙串私钥访问授权，而非 Apple 时间戳服务。`security find-identity` 可列出该有效身份，但这不证明私钥授权已正常工作。
- 因 DMG 未生成，本版本尚未提交 Apple 公证、装订公证票据或通过 Gatekeeper 验证。之前的公证记录属于旧构建，不能作为本版本的证据。
- 本记录编写时，Build 21 的版本号更改和本记录尚未提交或推送；其后续同步状态以 Git 历史为准。

## 后续

1. 确认 App Store Connect 处理完成，关联 Build 21 到 2.0.3 并完成审核资料。
2. 排查并修复登录钥匙串中 ZEAN LI Developer ID 私钥的 `codesign` 访问授权。
3. 重新构建 2.0.3 Build 21 DMG，完成 Apple 公证、stapler 验证和 Gatekeeper 检查。
4. 提交版本号与发布记录变更，并继续完成审核提交。
