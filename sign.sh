#!/bin/bash
# ============================================================
# 残留清理助手 - 签名 & 打包脚本
#
# 用法:
#   ./sign.sh              # 签名 + 打包 DMG（不发公证）
#   ./sign.sh --notarize   # 签名 + 打包 + 公证（需要 API Key）
# ============================================================

set -e

APP_NAME="残留清理助手"
APP_PATH="Build/$APP_NAME.app"
DMG_NAME="${APP_NAME}.dmg"
DEV_TEAM="SXC84F45PT"

cd "$(dirname "$0")"

# ── 检查 App 是否存在 ──
if [ ! -d "$APP_PATH" ]; then
    echo "❌ 找不到 $APP_PATH"
    echo "   请先运行 ./build.sh"
    exit 1
fi

# ── 查找 Developer ID 证书 ──
echo "🔍 查找 Developer ID 证书..."
CERT_HASH=$(security find-identity -v -p basic 2>/dev/null | grep "Developer ID Application" | head -1 | grep -oE '[A-F0-9]{40}')

if [ -z "$CERT_HASH" ]; then
    echo "❌ 未找到 Developer ID Application 证书！"
    echo "   请先在 developer.apple.com 下载安装"
    exit 1
fi
echo "✅ 找到: $(security find-identity -v -p basic 2>/dev/null | grep "$CERT_HASH" | sed 's/.*"//')"

# ── 签名 ──
echo "✍️  签名中..."
codesign --force --deep --options runtime \
  --sign "$CERT_HASH" \
  "$APP_PATH"
echo "✅ 签名完成"

# ── 验证签名 ──
echo "🔎 验证签名..."
codesign -dvvv "$APP_PATH" 2>&1 | grep -E "Authority|TeamIdentifier|Sealed"
echo ""

# ── 可选：公证 ──
if [ "$1" = "--notarize" ]; then
    echo "📋 准备公证..."

    # 检查 API Key 环境变量
    if [ -z "$NOTARIZATION_KEY_ID" ] || [ -z "$NOTARIZATION_ISSUER_ID" ] || [ -z "$NOTARIZATION_KEY_PATH" ]; then
        echo "❌ 缺少公证所需的 API Key 环境变量："
        echo ""
        echo "  export NOTARIZATION_KEY_ID=\"你的KeyID\""
        echo "  export NOTARIZATION_ISSUER_ID=\"你的IssuerID\""
        echo "  export NOTARIZATION_KEY_PATH=\"/path/to/AuthKey_XXXXX.p8\""
        echo ""
        echo "获取方式: https://appstoreconnect.apple.com/access/integrations/api"
        exit 1
    fi

    # 打包
    echo "📦 打包为 app.zip..."
    rm -f app.zip
    ditto -c -k --keepParent "$APP_PATH" app.zip

    # 提交公证
    echo "📋 提交公证（约 1-3 分钟）..."
    xcrun notarytool submit app.zip \
        --key "$NOTARIZATION_KEY_PATH" \
        --key-id "$NOTARIZATION_KEY_ID" \
        --issuer "$NOTARIZATION_ISSUER_ID" \
        --output-format json \
        --wait > notary_result.json

    STATUS=$(python3 -c "import json;print(json.load(open('notary_result.json')).get('status','unknown'))" 2>/dev/null)
    echo "📋 状态: $STATUS"

    if [ "$STATUS" != "Accepted" ]; then
        echo "❌ 公证失败"
        cat notary_result.json
        exit 1
    fi

    # 装订
    echo "📎 装订公证票据..."
    xcrun stapler staple "$APP_PATH"
    echo "✅ 装订完成"
fi

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
  "$DMG_NAME" 2>/dev/null

rm -rf dmg_staging app.zip notary_result.json 2>/dev/null

echo ""
echo "🎉 全部完成！"
echo "   文件: $(pwd)/$DMG_NAME"
if [ "$1" = "--notarize" ]; then
    echo "   用户双击可直接打开 ✅"
else
    echo "   用户首次打开需去「设置 → 隐私与安全性 → 仍要打开」"
    echo "   后续用 ./sign.sh --notarize 可去掉这个提示"
fi
echo ""
echo "   给 DMG 签名（推荐，可选）:"
echo "     codesign --sign \"$CERT_HASH\" \"$DMG_NAME\""
