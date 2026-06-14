#!/bin/bash
# ============================================================
# 残留清理助手 - 构建脚本
# 用法: ./build.sh
# ============================================================

set -e

APP_NAME="残留清理助手"
BUNDLE_ID="com.orphancleaner.app"
BUILD_DIR=".build"
OUTPUT_DIR="Build"

echo "🔨 开始构建..."

cd "$(dirname "$0")"

# 1. 编译
echo "📦 编译中..."
swift build -c release --product OrphanCleaner

# 2. 创建 .app 包结构
echo "📁 创建 App 包..."
APP_PATH="$OUTPUT_DIR/$APP_NAME.app"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# 3. 复制二进制
BINARY="$BUILD_DIR/release/OrphanCleaner"
if [ ! -f "$BINARY" ]; then
    BINARY="$BUILD_DIR/arm64-apple-macosx/release/OrphanCleaner"
fi

if [ ! -f "$BINARY" ]; then
    echo "❌ 找不到编译产物！"
    find "$BUILD_DIR" -name "OrphanCleaner" -type f 2>/dev/null
    exit 1
fi

cp "$BINARY" "$APP_PATH/Contents/MacOS/OrphanCleaner"

# 4. 复制 Info.plist
cp "Sources/OrphanCleaner/Resources/Info.plist" "$APP_PATH/Contents/"

# 5. 复制资源
if [ -d "Sources/OrphanCleaner/Resources" ]; then
    cp -r Sources/OrphanCleaner/Resources/* "$APP_PATH/Contents/Resources/" 2>/dev/null || true
fi

# 6. 创建 PkgInfo
echo "APPL????" > "$APP_PATH/Contents/PkgInfo"

echo ""
echo "✅ 构建完成！"
echo "   位置: $(pwd)/$APP_PATH"
echo ""
echo "   下一步: ./sign.sh（打包签名分发）"
