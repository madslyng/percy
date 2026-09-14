#!/usr/bin/env bash
# Installs the percy-screenshot scripts and systemd --user timer.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

mkdir -p "$BIN_DIR" "$SYSTEMD_USER_DIR"

install -m 755 "$SCRIPT_DIR/percy-screenshot.sh" "$BIN_DIR/percy-screenshot.sh"
install -m 755 "$SCRIPT_DIR/percy-screenshot-ctl.sh" "$BIN_DIR/percy-screenshot-ctl.sh"
install -m 644 "$SCRIPT_DIR/percy-screenshot.service" "$SYSTEMD_USER_DIR/percy-screenshot.service"
install -m 644 "$SCRIPT_DIR/percy-screenshot.timer" "$SYSTEMD_USER_DIR/percy-screenshot.timer"

if ! command -v maim >/dev/null 2>&1 && ! command -v scrot >/dev/null 2>&1 && ! command -v import >/dev/null 2>&1; then
    echo "warning: no screenshot tool found. Install one of: maim, scrot, imagemagick" >&2
fi

systemctl --user daemon-reload
systemctl --user enable --now percy-screenshot.timer

cat <<EOF

Installed:
  $BIN_DIR/percy-screenshot.sh
  $BIN_DIR/percy-screenshot-ctl.sh
  $SYSTEMD_USER_DIR/percy-screenshot.service
  $SYSTEMD_USER_DIR/percy-screenshot.timer

The timer is enabled and running (screenshots every minute).
Screenshots are saved to: ${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}

To add the i3blocks status/toggle indicator, add this block to your
i3blocks config (~/.config/i3blocks/config):

$(sed -n '/^\[percy-screenshot\]/,$p' "$SCRIPT_DIR/i3blocks.conf")

Then reload i3 (\$mod+Shift+r) or restart i3blocks.
EOF
