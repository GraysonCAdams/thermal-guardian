#!/bin/bash
set -euo pipefail

PLIST_NAME="com.user.thermal-guardian.plist"
PLIST_DST="$HOME/Library/LaunchAgents/${PLIST_NAME}"

echo "Thermal Guardian Uninstaller"
echo "============================"

# 1. Unload the agent
echo "[1/2] Unloading launch agent..."
launchctl unload "$PLIST_DST" 2>/dev/null || true

# 2. Remove the plist
echo "[2/2] Removing plist from ~/Library/LaunchAgents/..."
rm -f "$PLIST_DST"

echo ""
echo "Thermal Guardian has been uninstalled."
echo "The monitoring script and repo remain at: $(cd "$(dirname "$0")" && pwd)"
echo "Log files remain at: ~/Library/Logs/ThermalGuardian*.log"
echo ""
echo "To also remove logs:  rm ~/Library/Logs/ThermalGuardian*.log"
