#!/bin/bash
# ============================================================
# GitHub Secrets 设置助手（已配置版）
# 
# 如果需要重新上传证书（比如证书过期后重做），运行：
#   bash scripts/github-secrets-helper.sh
# ============================================================

set -e

echo "========================================"
echo " 🔐 GitHub Secrets 状态"
echo "========================================"
echo ""

# 检查 gh 是否登录
if ! gh auth status 2>/dev/null >&2; then
  echo "❌ 请先登录 GitHub CLI: gh auth login"
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
echo "仓库: $REPO"
echo ""

echo "已配置的 Secrets："
gh secret list 2>/dev/null
echo ""

echo "========================================"
echo " 如需重新上传证书（证书过期时）："
echo "========================================"
echo ""
echo "  bash scripts/github-secrets-helper.sh"
echo ""
echo "  security export -k ~/Library/Keychains/login.keychain-db \\"
echo "    -t identities -f pkcs12 \\"
echo "    -o /tmp/cert.p12 -P \"你的密码\""
echo ""
echo "  base64 -i /tmp/cert.p12 | gh secret set DEVELOPER_ID_P12 --repo $REPO"
echo "  echo \"你的密码\" | gh secret set DEVELOPER_ID_PASSWORD --repo $REPO"
echo "  rm -f /tmp/cert.p12"
echo ""
