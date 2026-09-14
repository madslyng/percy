#!/usr/bin/env bash
# Removes the percy-screenshot scripts, service, and timer installed by install.sh.
set -euo pipefail

BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

systemctl --user disable --now percy-screenshot.timer 2>/dev/null || true
systemctl --user stop percy-screenshot.service 2>/dev/null || true

rm -f "$SYSTEMD_USER_DIR/percy-screenshot.service" "$SYSTEMD_USER_DIR/percy-screenshot.timer"
rm -f "$BIN_DIR/percy-screenshot.sh" "$BIN_DIR/percy-screenshot-ctl.sh"

systemctl --user daemon-reload
systemctl --user reset-failed percy-screenshot.service percy-screenshot.timer 2>/dev/null || true

echo "Uninstalled percy-screenshot service, timer, and scripts."
echo "If you added the percy-screenshot block to your i3blocks config, remove it manually."
