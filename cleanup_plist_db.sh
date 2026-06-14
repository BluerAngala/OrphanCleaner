#!/bin/bash
# 清理系统 disabled.plist 中的残留条目
set -e

PLIST="/var/db/com.apple.xpc.launchd/disabled.plist"
BACKUP="/var/db/com.apple.xpc.launchd/disabled.plist.bak"

echo ">>> 备份原文件..."
sudo cp "$PLIST" "$BACKUP"

echo ">>> 删除残留条目..."
sudo /usr/libexec/PlistBuddy -c "Delete :com.docker.socket" "$PLIST" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :com.docker.vmnetd" "$PLIST" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :com.youqu.todesk.service" "$PLIST" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :com.youqu.todesk.UninstallerHelper" "$PLIST" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :com.youqu.todesk.UninstallerWatcher" "$PLIST" 2>/dev/null || true
sudo /usr/libexec/PlistBuddy -c "Delete :io.github.clash-verge-rev.clash-verge-rev.service" "$PLIST" 2>/dev/null || true

echo ""
echo ">>> 清理后内容："
sudo /usr/libexec/PlistBuddy -c "Print" "$PLIST"

echo ""
echo "✅ 系统级残留清理完成"
