#!/usr/bin/env bash
# Status/control script for percy-screenshot.timer.
# Usable both as a CLI (status|enable|disable|toggle) and as an i3blocks
# blocklet (default "block" mode), where a double left-click toggles the timer.
set -euo pipefail

TIMER_UNIT="percy-screenshot.timer"
DOUBLE_CLICK_MS=400
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/percy-screenshot-block-last-click"

is_active() {
    systemctl --user is-active --quiet "$TIMER_UNIT"
}

do_enable() {
    systemctl --user enable --now "$TIMER_UNIT"
}

do_disable() {
    systemctl --user disable --now "$TIMER_UNIT"
}

do_toggle() {
    if is_active; then
        do_disable
    else
        do_enable
    fi
}

print_block() {
    local state color
    if is_active; then
        state="on"
        color="#00FF00"
    else
        state="off"
        color="#FF0000"
    fi
    echo "📷 screenshot: ${state}"
    echo "📷 ${state}"
    echo "${color}"
}

# Detects a double left-click by comparing timestamps across invocations.
is_double_click() {
    local now last
    now="$(date +%s%3N)"
    last="$(cat "$STATE_FILE" 2>/dev/null || echo 0)"
    echo "$now" >"$STATE_FILE"
    (( now - last <= DOUBLE_CLICK_MS ))
}

run_block_mode() {
    if [[ "${BLOCK_BUTTON:-}" == "1" ]] && is_double_click; then
        do_toggle
    fi
    print_block
}

case "${1:-block}" in
    status) is_active && echo on || echo off ;;
    enable|start|on) do_enable ;;
    disable|stop|off) do_disable ;;
    toggle) do_toggle ;;
    block) run_block_mode ;;
    *)
        echo "Usage: $0 {status|enable|disable|toggle|block}" >&2
        exit 1
        ;;
esac
