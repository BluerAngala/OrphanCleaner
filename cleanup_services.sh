#!/bin/bash
# 清理后台自动启动服务
set -e

echo ">>> 停止运行中的服务..."
sudo launchctl bootout system /Library/LaunchDaemons/com.youqu.todesk.service.plist 2>/dev/null || true
sudo launchctl bootout gui/$(id -u) /Library/LaunchAgents/com.youqu.todesk.session.plist 2>/dev/null || true

echo ""
echo ">>> 删除 plist 文件..."

# ToDesk (5个)
sudo rm -f /Library/LaunchDaemons/com.youqu.todesk.service.plist
sudo rm -f /Library/LaunchDaemons/com.youqu.todesk.UninstallerHelper.plist
sudo rm -f /Library/LaunchDaemons/com.youqu.todesk.UninstallerWatcher.plist
sudo rm -f /Library/LaunchAgents/com.youqu.todesk.session.plist
sudo rm -f /Library/LaunchAgents/com.youqu.todesk.startup.plist

# Docker (2个)
sudo rm -f /Library/LaunchDaemons/com.docker.socket.plist
sudo rm -f /Library/LaunchDaemons/com.docker.vmnetd.plist

# Clash Verge Rev (1个)
sudo rm -f /Library/LaunchDaemons/io.github.clash-verge-rev.clash-verge-rev.service.plist

echo ""
echo "✅ 清理完成！剩余的系统服务："
ls /Library/LaunchDaemons/ /Library/LaunchAgents/ 2>/dev/null
