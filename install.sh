#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.user.thermal-guardian.plist"
PLIST_SRC="${SCRIPT_DIR}/${PLIST_NAME}"
PLIST_DST="$HOME/Library/LaunchAgents/${PLIST_NAME}"
SCRIPT_PATH="${SCRIPT_DIR}/thermal-guardian.sh"

echo "Thermal Guardian Installer"
echo "=========================="

# 1. Make the monitoring script executable
echo "[1/3] Making thermal-guardian.sh executable..."
chmod +x "$SCRIPT_PATH"

# 2. Copy plist to LaunchAgents
echo "[2/3] Installing plist to ~/Library/LaunchAgents/..."
mkdir -p "$HOME/Library/LaunchAgents"
launchctl unload "$PLIST_DST" 2>/dev/null || true
cp "$PLIST_SRC" "$PLIST_DST"

# 3. Load the agent
echo "[3/3] Loading launch agent..."
launchctl load "$PLIST_DST"

echo ""
echo "Thermal Guardian is now active."
echo "  Monitor:    tail -f ~/Library/Logs/ThermalGuardian.log"
echo "  Status:     launchctl list | grep thermal-guardian"
echo "  Uninstall:  ./uninstall.sh"
