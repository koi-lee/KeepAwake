# 发布说明

## 发布方式

KeepAwake 是独立 macOS 应用，通过 GitHub Releases 分发 DMG，不使用服务器、Docker、数据库或运行时环境变量。

```bash
./build.sh --dmg
```

发布前确认：

- `TESTING.md` 中的编译、睡眠模式和合盖模式验证通过。
- 明确说明当前签名、公证状态、macOS 最低版本和管理员授权要求。
- Release 说明包含 DMG 安装、首次打开和隐私行为说明。
- 不把证书、私钥、真实用户配置或日志上传到 GitHub。

## 回滚

保留上一版 GitHub Release；新版本出现问题时恢复到上一版安装包，不删除历史 Release。

