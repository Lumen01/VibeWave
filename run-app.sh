#!/bin/bash

# VibeWave macOS App Build Script
# Usage: ./run-app.sh [--build|--run] [--release]
#   --build: Build only, don't launch
#   --run:   Build and launch (default)
#   --release: Build with the release configuration (debug is the default)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
APP_NAME="VibeWave"
ICON_SRC="$SCRIPT_DIR/art/VibeWave.icns"

# Parse arguments
MODE="--run"
BUILD_CONFIG="debug"
for option in "$@"; do
    case "$option" in
        --build|--run)
            MODE="$option"
            ;;
        --release)
            BUILD_CONFIG="release"
            ;;
        *)
            echo "❌ Unknown option: $option"
            echo "Usage: $0 [--build|--run] [--release]"
            echo "  --build:   Build only, don't launch"
            echo "  --run:     Build and launch (default)"
            echo "  --release: Build with the release configuration (debug is the default)"
            exit 1
            ;;
    esac
done

# ========== 版本号管理 ==========
# 发布构建使用当前提交的准确标签；研发构建使用仓库内的版本文件。
VERSION_FILE="$SCRIPT_DIR/.version"
if [[ -f "$VERSION_FILE" ]]; then
    VERSION=$(cat "$VERSION_FILE")
else
    echo "❌ Missing .version; set the development version before building"
    exit 1
fi
if [[ ! "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo "❌ Invalid semantic version: $VERSION"
    exit 1
fi
if [[ "$GITHUB_REF_TYPE" == "tag" && "$GITHUB_REF_NAME" != "v$VERSION" ]]; then
    echo "❌ Release tag must be v$VERSION to match .version"
    exit 1
fi

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

if [[ ! "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]]; then
    echo "❌ Invalid build number: $BUILD_NUMBER"
    exit 1
fi
echo "$BUILD_NUMBER" > "$BUILD_NUMBER_FILE"

# ========== 构建信息 ==========
BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
SOURCE_REF="${GITHUB_REF_NAME:-$GIT_BRANCH}"
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
    GIT_COMMIT="$GIT_COMMIT-dirty"
fi

echo "📦 Version: $VERSION (Build $BUILD_NUMBER)"
echo "🔨 Commit: $GIT_COMMIT"
echo "📅 Date: $BUILD_DATE"

# ========== 构建 Swift 项目 ==========
echo "🏗️  Building VibeWave ($BUILD_CONFIG)..."
BUILD_DIR=$(swift build -c "$BUILD_CONFIG" --show-bin-path)
swift build -c "$BUILD_CONFIG"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"

# ========== 创建 .app Bundle ==========
echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$CONTENTS/Resources"

echo "📋 Copying executable..."
cp "$BUILD_DIR/VibeWave" "$MACOS/$APP_NAME"
chmod +x "$MACOS/$APP_NAME"

echo "📋 Copying resource bundle..."
RESOURCE_BUNDLE=""
if [[ -d "$BUILD_DIR/VibeWave_VibeWave.bundle" ]]; then
    RESOURCE_BUNDLE="$BUILD_DIR/VibeWave_VibeWave.bundle"
fi

if [[ -n "$RESOURCE_BUNDLE" && -d "$RESOURCE_BUNDLE" ]]; then
    cp -R "$RESOURCE_BUNDLE" "$CONTENTS/Resources/"
    echo "✅ Copied resource bundle from $RESOURCE_BUNDLE"
else
    echo "❌ Resource bundle not found"
    exit 1
fi

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
    <key>VibeWaveSourceRevision</key>
    <string>$GIT_COMMIT</string>
    <key>VibeWaveSourceBranch</key>
    <string>$GIT_BRANCH</string>
    <key>VibeWaveSourceRef</key>
    <string>$SOURCE_REF</string>
    <key>VibeWaveBuildConfiguration</key>
    <string>$BUILD_CONFIG</string>
    <key>VibeWaveBuildDate</key>
    <string>$BUILD_DATE</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

# ========== 代码签名 ==========
echo "🔏 Code signing..."
if [[ -n "$GITHUB_RUN_NUMBER" ]]; then
    # CI 环境：使用 ad-hoc 签名
    codesign --force --deep --sign - "$APP_BUNDLE"
else
    # 本地环境：使用 ad-hoc 签名
    codesign --force --deep --sign - "$APP_BUNDLE"
fi
echo "✅ Code signed"

# ========== 启动或仅构建 ==========
case "$MODE" in
  --build)
    echo "✅ Build complete!"
    echo "   Version: $VERSION (Build $BUILD_NUMBER)"
    echo "   App bundle: $APP_BUNDLE"
    ;;
  --run)
    echo "🚀 Launching app..."
    open "$APP_BUNDLE"
    echo "✅ VibeWave launched!"
    ;;
esac
