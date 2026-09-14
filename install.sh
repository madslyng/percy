#!/usr/bin/env bash
# Installs the percy-screenshot scripts and systemd --user timer.
# Safe to re-run: fully regenerates the timer (use -i/--interval to change
# the capture interval on an already-installed service).
set -euo pipefail

INTERVAL_MINUTES=1

usage() {
    echo "Usage: $0 [-i|--interval MINUTES]" >&2
    echo "  MINUTES: how often to capture a screenshot (default: 1)" >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--interval)
            INTERVAL_MINUTES="${2:-}"
            shift 2
            ;;
        --interval=*)
            INTERVAL_MINUTES="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "error: unknown argument: $1" >&2
            usage
            exit 1
            ;;
    esac
done

if ! [[ "$INTERVAL_MINUTES" =~ ^[0-9]+$ ]] || [[ "$INTERVAL_MINUTES" -lt 1 ]]; then
    echo "error: --interval must be a positive integer (minutes), got: $INTERVAL_MINUTES" >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"

mkdir -p "$BIN_DIR" "$SYSTEMD_USER_DIR"

install -m 755 "$SCRIPT_DIR/percy-screenshot.sh" "$BIN_DIR/percy-screenshot.sh"
install -m 755 "$SCRIPT_DIR/percy-screenshot-ctl.sh" "$BIN_DIR/percy-screenshot-ctl.sh"
install -m 755 "$SCRIPT_DIR/percy-timelapse.sh" "$BIN_DIR/percy-timelapse.sh"
install -m 644 "$SCRIPT_DIR/percy-screenshot.service" "$SYSTEMD_USER_DIR/percy-screenshot.service"
sed "s/%%INTERVAL_MINUTES%%/$INTERVAL_MINUTES/g" "$SCRIPT_DIR/percy-screenshot.timer" >"$SYSTEMD_USER_DIR/percy-screenshot.timer"
chmod 644 "$SYSTEMD_USER_DIR/percy-screenshot.timer"
install -m 644 "$SCRIPT_DIR/percy-timelapse.service" "$SYSTEMD_USER_DIR/percy-timelapse.service"
install -m 644 "$SCRIPT_DIR/percy-timelapse.timer" "$SYSTEMD_USER_DIR/percy-timelapse.timer"

if ! command -v maim >/dev/null 2>&1 && ! command -v scrot >/dev/null 2>&1 && ! command -v import >/dev/null 2>&1; then
    echo "warning: no screenshot tool found. Install one of: maim, scrot, imagemagick" >&2
fi

systemctl --user daemon-reload
systemctl --user enable --now percy-screenshot.timer
# Re-running enable --now on an already-active timer doesn't reload its
# schedule, so force a restart to pick up an interval change.
systemctl --user restart percy-screenshot.timer

if command -v ffmpeg >/dev/null 2>&1; then
    systemctl --user enable --now percy-timelapse.timer
else
    echo "warning: ffmpeg not found; percy-timelapse.timer installed but not enabled." >&2
    echo "  Install ffmpeg, then: systemctl --user enable --now percy-timelapse.timer" >&2
fi

cat <<EOF

Installed:
  $BIN_DIR/percy-screenshot.sh
  $BIN_DIR/percy-screenshot-ctl.sh
  $BIN_DIR/percy-timelapse.sh
  $SYSTEMD_USER_DIR/percy-screenshot.service
  $SYSTEMD_USER_DIR/percy-screenshot.timer
  $SYSTEMD_USER_DIR/percy-timelapse.service
  $SYSTEMD_USER_DIR/percy-timelapse.timer

The timer is enabled and running (screenshots every $INTERVAL_MINUTES minute(s)).
Screenshots are saved to: ${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}

If ffmpeg is installed, today's timelapse regenerates every hour on the hour
at: ${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}/timelapse_<today>_to_<today>.mp4

To add the i3blocks status/toggle indicator, add this block to your
i3blocks config (~/.config/i3blocks/config):

$(sed -n '/^\[percy-screenshot\]/,$p' "$SCRIPT_DIR/i3blocks.conf")

Then reload i3 (\$mod+Shift+r) or restart i3blocks.
EOF
