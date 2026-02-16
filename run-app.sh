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

APP_CONFIG_FILE="$SCRIPT_DIR/Sources/VibeWave/AppConfiguration.swift"

BUILD_NUMBER=$(grep -o 'buildNumber = [0-9]*' "$APP_CONFIG_FILE" | grep -o '[0-9]*')
BUILD_NUMBER=$((BUILD_NUMBER + 1))

BUILD_DATE=$(date +"%Y-%m-%d %H:%M:%S")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

if [[ -f "$APP_CONFIG_FILE" ]]; then
  sed -i '' "s/public static let buildNumber = [0-9]*/public static let buildNumber = $BUILD_NUMBER/" "$APP_CONFIG_FILE"
  sed -i '' "s/public static let buildDate = \"[^\"]*\"/public static let buildDate = \"$BUILD_DATE\"/" "$APP_CONFIG_FILE"
  sed -i '' "s/public static let gitCommit = \"[^\"]*\"/public static let gitCommit = \"$GIT_COMMIT\"/" "$APP_CONFIG_FILE"
  echo "📊 Build #$BUILD_NUMBER ($GIT_COMMIT) on $BUILD_DATE"
fi

echo "🏗️  Building VibeWave..."
swift build

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

echo "⚙️  Creating Info.plist..."
cat > "$CONTENTS/Info.plist" <<'EOF'
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
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

case "$MODE" in
  --build)
    echo "✅ Build complete!"
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
