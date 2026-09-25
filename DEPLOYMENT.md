# 发布说明

当前待发布版本：2.0.3（构建 21）。Build 21 已由 Xcode 上传到 App Store Connect，等待 Apple 处理；尚未确认处理完成、关联到版本页面或提交审核。独立分发 DMG 尚未生成：本机 `codesign` 在调用 `Developer ID Application: ZEAN LI (4BHPD976HX)` 私钥时持续等待，需先解决钥匙串授权，再签名和公证本版本 DMG。

App Store Connect 已拒收 2.0.1（构建 20）：2.0.1 版本线已关闭，且已批准版本为 2.0.2；构建号 20 也已被使用。因此本次发布版本提升至 2.0.3（构建 21）。

## 发布方式

KeepAwake 是独立 macOS 应用，通过 GitHub Releases 分发 DMG，不使用服务器、Docker、数据库或运行时环境变量。

```bash
./build.sh --dmg
```

## Developer ID 签名故障排查

KeepAwake 的独立 DMG 必须使用 `Developer ID Application` 证书；`Apple Distribution` 证书只适用于 App Store Connect，不能替代 Developer ID。当前构建脚本要求的签名身份是：

```text
Developer ID Application: ZEAN LI (4BHPD976HX)
```

### 常见症状

- `security find-identity -v -p codesigning` 能看到证书，但 `./build.sh --dmg` 在签名阶段长时间没有输出。
- `dist/KeepAwake.dmg` 没有生成，或 App 内出现 `.cstemp` 临时文件。
- `spctl -a -vv --type execute dist/KeepAwake.app` 显示 `Unnotarized Developer ID`。

### 排查顺序

1. 确认目标身份存在：

   ```bash
   security find-identity -v -p codesigning
   ```

2. 用一个临时文件测试私钥是否能被 `codesign` 实际调用。证书出现在列表中，只能说明签名身份可被识别，不能证明私钥访问没有卡住。
3. 如果 `codesign` 超时，打开“钥匙串访问”，确认 `login.keychain-db` 中存在与目标 Developer ID 证书配对的私钥，并允许签名工具访问。不要删除其他项目正在使用的证书，也不要把钥匙串密码或 `.p12` 私钥提交到仓库。
4. 清理并重新运行：

   ```bash
   ./build.sh --dmg
   codesign --verify --deep --strict dist/KeepAwake.app
   ```

5. 检查实际签名身份：

   ```bash
   codesign -dv --verbose=4 dist/KeepAwake.app 2>&1 | rg 'Authority=|TeamIdentifier='
   ```

### 签名、公证和票据是三个不同状态

- `codesign --verify` 通过：表示 App 已签名且结构有效。
- `spctl` 显示 `Unnotarized Developer ID`：表示已使用 Developer ID，但尚未完成 Apple 公证。
- `xcrun stapler validate dist/KeepAwake.dmg` 通过：表示公证票据已装订到 DMG；失败或提示没有 ticket，不能写成“已公证”。

本次故障的根因是：`ZEAN LI` 证书可以被系统识别，但 `codesign` 调用对应私钥时卡住；修复钥匙串访问后，App 签名和 DMG 创建均恢复正常。本次公证提交 `001ab3ae-5ec8-4801-8cd1-c4739696377b` 已获 Apple 接受，票据已装订，并通过挂载后 Gatekeeper 验证；后续发布时仍需核对上传的 Release 资产就是这份已公证包。

发布前确认：

- `TESTING.md` 中的编译、睡眠模式和合盖模式验证通过。
- 明确说明当前签名、公证状态、macOS 最低版本和管理员授权要求。
- Release 说明包含 DMG 安装、首次打开和隐私行为说明。
- 不把证书、私钥、真实用户配置或日志上传到 GitHub。

## 回滚

保留上一版 GitHub Release；新版本出现问题时恢复到上一版安装包，不删除历史 Release。
