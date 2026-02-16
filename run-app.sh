#!/bin/bash

# VibeWave macOS App Build Script
# Usage: ./run-app.sh [--build|--run]
#   --build: Build only, don't launch
#   --run:   Build and launch (default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build/debug"
APP_NAME="VibeWave"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
ICON_SRC="$SCRIPT_DIR/art/VibeWave.icns"

# Parse arguments
MODE="${1:---run}"

# ========== 版本号管理 ==========
# 1. 尝试从 Git 标签获取版本（优先级最高）
VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "")

# 2. 如果没有标签，从 VERSION 文件读取
VERSION_FILE="$SCRIPT_DIR/.version"
if [[ -z "$VERSION" && -f "$VERSION_FILE" ]]; then
    VERSION=$(cat "$VERSION_FILE")
fi

# 3. 默认版本
VERSION="${VERSION:-1.0.0}"

# 保存版本到文件（供后续使用）
echo "$VERSION" > "$VERSION_FILE"

# ========== Build Number 管理 ==========
BUILD_NUMBER_FILE="$SCRIPT_DIR/.build_number"
if [[ -f "$BUILD_NUMBER_FILE" ]]; then
    BUILD_NUMBER=$(cat "$BUILD_NUMBER_FILE")
else
    BUILD_NUMBER=0
fi

# CI 环境：使用 GitHub Run Number
if [[ -n "$GITHUB_RUN_NUMBER" ]]; then
    BUILD_NUMBER=$GITHUB_RUN_NUMBER
# 本地环境：自动递增
else
    BUILD_NUMBER=$((BUILD_NUMBER + 1))
fi

echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

# ========== 构建信息 ==========
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

echo "📦 Version: $VERSION (Build $BUILD_NUMBER)"
echo "🔨 Commit: $GIT_COMMIT"
echo "📅 Date: $BUILD_DATE"

# ========== 更新 AppConfiguration.swift ==========
APP_CONFIG_FILE="$SCRIPT_DIR/Sources/VibeWave/AppConfiguration.swift"
if [[ -f "$APP_CONFIG_FILE" ]]; then
    sed -i '' "s/buildNumber = [0-9]*/buildNumber = $BUILD_NUMBER/" "$APP_CONFIG_FILE"
    sed -i '' "s/buildDate = \"[^\"]*\"/buildDate = \"$BUILD_DATE\"/" "$APP_CONFIG_FILE"
    sed -i '' "s/gitCommit = \"[^\"]*\"/gitCommit = \"$GIT_COMMIT\"/" "$APP_CONFIG_FILE"
    echo "✅ Updated AppConfiguration.swift"
fi

# ========== 构建 Swift 项目 ==========
echo "🏗️  Building VibeWave..."
swift build

# ========== 创建 .app Bundle ==========
echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"

echo "📋 Copying executable..."
cp "$BUILD_DIR/VibeWave" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

if [[ -f "$ICON_SRC" ]]; then
    echo "🎨 Copying app icon..."
    cp "$ICON_SRC" "$CONTENTS/Resources/VibeWave.icns"
fi

# ========== 创建 Info.plist（包含版本号）==========
echo "⚙️  Creating Info.plist with version $VERSION (build $BUILD_NUMBER)..."
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>VibeWave</string>
    <key>CFBundleIdentifier</key>
    <string>com.lumen.VibeWave</string>
    <key>CFBundleIconFile</key>
    <string>VibeWave.icns</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>VibeWave</string>
    <key>CFBundleDisplayName</key>
    <string>VibeWave</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# ========== 启动或仅构建 ==========
case "$MODE" in
  --build)
    echo "✅ Build complete!"
    echo "   Version: $VERSION (Build $BUILD_NUMBER)"
    echo "   App bundle: $APP_BUNDLE"
    ;;
  --run|"")
    echo "🚀 Launching app..."
    open "$APP_BUNDLE"
    echo "✅ VibeWave launched!"
    ;;
  *)
    echo "❌ Unknown option: $MODE"
    echo "Usage: $0 [--build|--run]"
    echo "  --build: Build only, don't launch"
    echo "  --run:   Build and launch (default)"
    exit 1
    ;;
esac
