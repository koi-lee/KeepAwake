#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/dist"
APP_NAME="KeepAwake"
VERSION="2.0.2"
BUILD_NUM="20"
MIN_MACOS_VERSION="13.0"
EXPECTED_TEAM_ID="4BHPD976HX"
EXPECTED_SIGNING_IDENTITY="Developer ID Application: ZEAN LI ($EXPECTED_TEAM_ID)"
DMG_SIGNING_STATUS="Developer ID 签名 · 未经 Apple 公证"
BUILD_DMG=false
if [ "${1:-}" = "--dmg" ]; then
    BUILD_DMG=true
fi

# 本地构建仍默认 Ad-hoc；正式 DMG 必须使用更名后的 Developer ID 证书。
SIGNING_IDENTITY="${KEEP_AWAKE_SIGNING_IDENTITY:--}"
if [ "$BUILD_DMG" = true ]; then
    SIGNING_IDENTITY="${KEEP_AWAKE_SIGNING_IDENTITY:-$EXPECTED_SIGNING_IDENTITY}"
    if [ "$SIGNING_IDENTITY" != "$EXPECTED_SIGNING_IDENTITY" ]; then
        echo "❌ 正式构建拒绝：签名身份必须是 $EXPECTED_SIGNING_IDENTITY" >&2
        exit 1
    fi
    security find-identity -v -p codesigning | grep -Fq "\"$EXPECTED_SIGNING_IDENTITY\"" || {
        echo "❌ 未找到有效证书：$EXPECTED_SIGNING_IDENTITY" >&2
        exit 1
    }
fi

# ─── 清理 & 创建输出目录 ───────────────────────────────────
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "🔨 编译 KeepAwake $VERSION ..."

# ─── 编译 ─────────────────────────────────────────────────
# 同时编译 Apple Silicon 与 Intel，合成 Universal 2 安装包
SOURCES=(
    "$PROJECT_DIR/Sources/KeepAwake/AppConfig.swift"
    "$PROJECT_DIR/Sources/KeepAwake/Session.swift"
    "$PROJECT_DIR/Sources/KeepAwake/PowerSafety.swift"
    "$PROJECT_DIR/Sources/KeepAwake/LoginItemManager.swift"
    "$PROJECT_DIR/Sources/KeepAwake/SettingsWindow.swift"
    "$PROJECT_DIR/Sources/KeepAwake/UsageGuideWindow.swift"
    "$PROJECT_DIR/Sources/KeepAwake/SleepGuard.swift"
    "$PROJECT_DIR/Sources/KeepAwake/LidSleepGuard.swift"
    "$PROJECT_DIR/Sources/KeepAwake/AppMatcher.swift"
    "$PROJECT_DIR/Sources/KeepAwake/AppSelectorWindow.swift"
    "$PROJECT_DIR/Sources/KeepAwake/SessionStatusWindow.swift"
    "$PROJECT_DIR/Sources/KeepAwake/AppDelegate.swift"
    "$PROJECT_DIR/Sources/KeepAwake/main.swift"
)
ARM_BINARY="$BUILD_DIR/${APP_NAME}-arm64"
INTEL_BINARY="$BUILD_DIR/${APP_NAME}-x86_64"
TMP_BINARY="$BUILD_DIR/${APP_NAME}-universal"

for ARCH in arm64 x86_64; do
    OUTPUT="$ARM_BINARY"
    if [ "$ARCH" = "x86_64" ]; then OUTPUT="$INTEL_BINARY"; fi
    xcrun --sdk macosx swiftc \
        -target "${ARCH}-apple-macos${MIN_MACOS_VERSION}" \
        -framework Cocoa -framework SwiftUI -framework IOKit -framework Network \
        -o "$OUTPUT" \
        "${SOURCES[@]}"
done
lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$TMP_BINARY"

# ─── 创建 .app Bundle ────────────────────────────────────
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/MacOS"
cp "$TMP_BINARY" "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
chmod +x "$BUILD_DIR/$APP_NAME.app/Contents/MacOS/$APP_NAME"
ICON_FILE="AppIcon.png"

# ─── 资源文件（图标 PNG） ─────────────────────────────────
mkdir -p "$BUILD_DIR/$APP_NAME.app/Contents/Resources"
# Dock 图标：由 1024×1024 PNG 生成标准 ICNS，避免 macOS 为旧式 PNG 图标补白色外框
ICON_PNG="$PROJECT_DIR/Sources/KeepAwake/AppIcon.png"
if [ -f "$ICON_PNG" ]; then
    ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"
    sips -z 16 16     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
    sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
    sips -z 32 32     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
    sips -z 64 64     "$ICON_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
    sips -z 128 128   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
    sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
    sips -z 256 256   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
    sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
    sips -z 512 512   "$ICON_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
    cp "$ICON_PNG" "$ICONSET_DIR/icon_512x512@2x.png"
    if iconutil -c icns "$ICONSET_DIR" -o "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.icns"; then
        ICON_FILE="AppIcon.icns"
    else
        echo "⚠️  当前系统无法转换 ICNS，回退使用 PNG 图标"
        cp "$ICON_PNG" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/AppIcon.png"
    fi
    rm -rf "$ICONSET_DIR"
fi
# 菜单栏图标 (64x64 黑白模板)
MENU_ICON="$PROJECT_DIR/Sources/KeepAwake/MenuBarIcon.png"
if [ -f "$MENU_ICON" ]; then
    cp "$MENU_ICON" "$BUILD_DIR/$APP_NAME.app/Contents/Resources/MenuBarIcon.png"
fi

# ─── Info.plist ──────────────────────────────────────────
cat > "$BUILD_DIR/$APP_NAME.app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>KeepAwake</string>
    <key>CFBundleExecutable</key>
    <string>KeepAwake</string>
    <key>CFBundleIconFile</key>
    <string>$ICON_FILE</string>
    <key>CFBundleIdentifier</key>
    <string>com.starshoreai.keepawake</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>KeepAwake</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUM</string>
    <key>LSMinimumSystemVersion</key>
    <string>$MIN_MACOS_VERSION</string>
    <key>LSMultipleInstancesProhibited</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

# ─── 清理 quarantine 属性 ─────────────────────────────────
xattr -cr "$BUILD_DIR/$APP_NAME.app"

# ─── 签名 ────────────────────────────────────────────────
# 本地开发默认 Ad-hoc；正式分发时传入 Developer ID Application 身份。
echo "🔐 签名身份: $SIGNING_IDENTITY"
if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --deep --sign "$SIGNING_IDENTITY" "$BUILD_DIR/$APP_NAME.app"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$BUILD_DIR/$APP_NAME.app"
fi
codesign --verify --deep --strict "$BUILD_DIR/$APP_NAME.app"

if [ "$BUILD_DMG" = true ]; then
    SIGNATURE_DETAILS="$(codesign -dvvv "$BUILD_DIR/$APP_NAME.app" 2>&1)"
    grep -Fq "Authority=$EXPECTED_SIGNING_IDENTITY" <<<"$SIGNATURE_DETAILS" || {
        echo "❌ 正式构建拒绝：产物证书姓名不正确" >&2
        exit 1
    }
    grep -Fq "TeamIdentifier=$EXPECTED_TEAM_ID" <<<"$SIGNATURE_DETAILS" || {
        echo "❌ 正式构建拒绝：产物 Team ID 不正确" >&2
        exit 1
    }
fi

echo "✅ 编译完成: $BUILD_DIR/$APP_NAME.app"
echo ""

# ─── 参数处理：--dmg ─────────────────────────────────────
if [ "$BUILD_DMG" = true ]; then
    echo "📦 正在创建 DMG 安装包 ..."

    DMG_STAGING="$BUILD_DIR/dmg-staging"
    DMG_FILE="$BUILD_DIR/${APP_NAME}.dmg"

    rm -rf "$DMG_STAGING" "$DMG_FILE"
    mkdir -p "$DMG_STAGING/.background"
    cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_STAGING/"
    ln -s /Applications "$DMG_STAGING/Applications"

    DMG_METADATA="版本 $VERSION ($BUILD_NUM)  ·  macOS ${MIN_MACOS_VERSION}+  ·  Universal 2 (Apple Silicon + Intel)  ·  $DMG_SIGNING_STATUS"
    DMG_BACKGROUND_TOOL="$BUILD_DIR/create-dmg-background"
    xcrun --sdk macosx swiftc \
        -framework AppKit \
        "$PROJECT_DIR/Scripts/DMGBackground.swift" \
        -o "$DMG_BACKGROUND_TOOL"
    "$DMG_BACKGROUND_TOOL" \
        "$DMG_STAGING/.background/DMGBackground.png" \
        "$DMG_METADATA"
    chmod 644 "$DMG_STAGING/.background/DMGBackground.png"
    if [ -f "$PROJECT_DIR/Scripts/DMG.DS_Store" ]; then
        cp "$PROJECT_DIR/Scripts/DMG.DS_Store" "$DMG_STAGING/.DS_Store"
    fi

    # 使用已在本机 Finder 验证过的 .DS_Store 模板，避免 CI 无桌面会话时依赖 Finder AppleScript。
    hdiutil create \
        -volname "$APP_NAME" \
        -srcfolder "$DMG_STAGING" \
        -ov \
        -format UDZO \
        -ov \
        "$DMG_FILE" >/dev/null

    rm -rf "$DMG_STAGING" "$DMG_BACKGROUND_TOOL"

    DMG_SIZE=$(du -h "$DMG_FILE" | cut -f1)
    echo "✅ DMG 创建成功: $DMG_FILE ($DMG_SIZE)"
    echo ""
    echo "分发方式："
    echo "  把 ${APP_NAME}.dmg 发给用户"
    echo "  用户双击挂载 → 拖拽 KeepAwake 到 Applications → 完成"
    echo "  首次打开被拦截：系统设置 → 隐私与安全性 → 仍要打开"
else
    echo "运行方式："
    echo "  open $BUILD_DIR/$APP_NAME.app"
    echo ""
    echo "打包 DMG 分发：./build.sh --dmg"
fi
