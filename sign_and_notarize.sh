#!/bin/bash
# ============================================================
# 本地签名 & 公证脚本
# 用法: ./sign_and_notarize.sh
# 
# 前置条件:
#   1. 钥匙串中已安装 Developer ID Application 证书
#   2. 已下载 App Store Connect API Key (AuthKey_XXXXX.p8)
#   3. 设置环境变量:
#      export NOTARIZATION_KEY_ID="XXXXXXXXXX"
#      export NOTARIZATION_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#      export NOTARIZATION_KEY_PATH="/path/to/AuthKey_XXXXX.p8"
#      export APPLE_TEAM_ID="你的TeamID"
# ============================================================

set -e

APP_NAME="残留清理助手"
APP_PATH="Build/$APP_NAME.app"
DMG_NAME="${APP_NAME}.dmg"

# ── 检查必要变量 ──
if [ -z "$NOTARIZATION_KEY_ID" ] || [ -z "$NOTARIZATION_ISSUER_ID" ] || [ -z "$NOTARIZATION_KEY_PATH" ]; then
  echo "❌ 请先设置环境变量："
  echo ""
  echo "  export NOTARIZATION_KEY_ID=\"你的KeyID\""
  echo "  export NOTARIZATION_ISSUER_ID=\"你的IssuerID\""
  echo "  export NOTARIZATION_KEY_PATH=\"/path/to/AuthKey_XXXXX.p8\""
  echo ""
  exit 1
fi

# ── 查找 Developer ID 证书 ──
echo "🔍 查找 Developer ID Application 证书..."
DEVELOPER_ID=$(security find-identity -v -p basic | grep "Developer ID Application" | head -1 | grep -oE '[A-F0-9]{40}')

if [ -z "$DEVELOPER_ID" ]; then
  echo "❌ 未找到 Developer ID Application 证书！"
  echo "   请先在 developer.apple.com 创建并安装到钥匙串"
  exit 1
fi
echo "✅ 找到证书: $DEVELOPER_ID"

# ── 查找 Team ID ──
TEAM_ID=${APPLE_TEAM_ID:-$(echo "$DEVELOPER_ID" | head -c 10)}
echo "📋 Team ID: $TEAM_ID"

# ── 签名 ──
echo "✍️  正在签名..."
codesign --force --deep --options runtime \
  --sign "$DEVELOPER_ID" \
  --entitlements <(cat <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
  <true/>
  <key>com.apple.security.cs.disable-library-validation</key>
  <true/>
</dict>
</plist>
EOF
) \
  "$APP_PATH"

echo "✅ 签名完成"

# ── 打包 ──
echo "📦 打包用于公证..."
rm -f app.zip
ditto -c -k --keepParent "$APP_PATH" app.zip

# ── 提交公证 ──
echo "📋 提交 Apple 公证（需等待 1-3 分钟）..."
xcrun notarytool submit app.zip \
  --key "$NOTARIZATION_KEY_PATH" \
  --key-id "$NOTARIZATION_KEY_ID" \
  --issuer "$NOTARIZATION_ISSUER_ID" \
  --output-format json \
  --wait > notary_result.json

NOTARY_STATUS=$(python3 -c "import json; print(json.load(open('notary_result.json')).get('status',''))" 2>/dev/null || echo "unknown")
echo "📋 公证状态: $NOTARY_STATUS"

if [ "$NOTARY_STATUS" != "Accepted" ]; then
  echo "❌ 公证失败！详情:"
  cat notary_result.json
  exit 1
fi

# ── 装订公证票据 ──
echo "📎 装订公证票据..."
xcrun stapler staple "$APP_PATH"
echo "✅ 装订完成"

# ── 创建 DMG ──
echo "💿 创建 DMG..."
rm -rf dmg_staging "$DMG_NAME"
mkdir -p dmg_staging
cp -r "$APP_PATH" dmg_staging/
ln -s /Applications dmg_staging/Applications

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder dmg_staging \
  -ov -format UDZO \
  "$DMG_NAME"

rm -rf dmg_staging app.zip notary_result.json

echo ""
echo "🎉 全部完成！"
echo "   DMG: $(pwd)/$DMG_NAME"
echo ""
echo "   可直接分发给用户，双击打开无任何警告 ✅"
