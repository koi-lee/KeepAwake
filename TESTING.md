# 测试指南

## 编译验证

```bash
swift build
./build.sh
```

## 本机功能验证

1. 打开 `dist/KeepAwake.app`，确认菜单栏图标出现。
2. 添加一个正在运行的 App，确认系统睡眠守护激活。
3. 退出目标 App，确认守护释放并按设置发送通知。
4. 分别验证系统睡眠、屏幕睡眠和合盖保活模式。
5. 验证配置保存、重启恢复、应用搜索和多显示器/全屏空间显示。
6. 合盖模式必须在连接电源、获得管理员授权的真实 Mac 上验证。

## 发布前检查

```bash
./build.sh --dmg
codesign --verify --deep --strict dist/KeepAwake.app
```

模拟器或单纯编译通过不能替代真实 macOS 电源行为验证。

