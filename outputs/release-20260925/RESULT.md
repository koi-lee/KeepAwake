# KeepAwake 2.0.3 Build 21 发布记录

日期：2026-09-25

## 已完成

- 将 App Store 版本提升为 `2.0.3`、构建号提升为 `21`。App Store Connect 拒绝 `2.0.1 (20)`：该版本线已关闭、已批准版本为 2.0.2，且构建号 20 已被使用。
- `swift test`：13 项通过，0 项失败。
- Xcode Release Archive：成功，归档版本 `2.0.3 (21)`，使用 `Apple Distribution: ZEAN LI (4BHPD976HX)`。
- Xcode 导出上传：返回 `Upload succeeded`，Build 21 已交给 App Store Connect 处理。
- Developer ID 正式 DMG：`./build.sh --dmg` 成功，版本 `2.0.3 (21)`，签名身份 `Developer ID Application: ZEAN LI (4BHPD976HX)`，签名含安全时间戳。
- Apple 公证：首次打包提交 `ed31c2b4-d8ad-43a6-a232-7e0a7240cac3` 已 `Accepted`；为目标电脑重新生成的交付包提交 `c80075ff-8053-4caf-b561-334b61005110` 也已 `Accepted`，并已对交付包 staple、通过 `xcrun stapler validate`。
- Gatekeeper：挂载 DMG 后 `spctl -a -vv --type execute` 返回 `accepted`、`source=Notarized Developer ID`。
- 当前交付 DMG SHA-256：`5b67616ff7a3c93f574ed53b8bb3d3e5b96c19a746ee71f4b69e6976dce94b36`。

## 尚未完成

- 本次操作后尚未再次读取 App Store Connect 页面，因此 Apple 的处理结果、Build 21 是否可选，以及 2.0.3 页面审核资料是否完整均未确认；也未提交审核。
- App Store Connect 的 Build 21 处理结果、是否可选及 2.0.3 页面资料是否完整，尚未在本次操作中回读；当前不声称已提交 App Store 审核。
- DMG 位于本机忽略目录 `dist/`，尚未上传到 GitHub Release；当前已生成给目标电脑实测的安装文件。
- 完整 App 的签名耗时长于小型探测包；确认 `codesign` 仍在运行后等待其完成，未再误判为卡死。

## 后续

1. 确认 App Store Connect 处理完成，关联 Build 21 到 2.0.3 并检查/完成审核资料；按用户此前授权提交审核并验证状态。
2. 若发布站外安装包，先核对上述 SHA-256，再上传此公证 DMG 到 GitHub Release。
