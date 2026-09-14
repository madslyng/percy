#!/usr/bin/env bash
# Captures a screenshot of the current display to $PERCY_SCREENSHOT_DIR,
# skipping the capture while the session is locked.
set -euo pipefail

SCREENSHOT_DIR="${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
RETENTION_DAYS="${PERCY_SCREENSHOT_RETENTION_DAYS:-7}"
LOCK_DETECT="${PERCY_LOCK_DETECT:-1}"
LOCKER_PROCESSES="${PERCY_LOCKER_PROCESSES:-i3lock light-locker xflock4 slock xtrlock xsecurelock betterlockscreen}"

mkdir -p "$SCREENSHOT_DIR"

# True if a screen locker is running or logind reports the session as locked.
is_locked() {
    [[ "$LOCK_DETECT" == "1" ]] || return 1

    local p
    for p in $LOCKER_PROCESSES; do
        pgrep -x "$p" >/dev/null 2>&1 && return 0
    done

    if command -v loginctl >/dev/null 2>&1; then
        local sid=""
        sid="${XDG_SESSION_ID:-}"
        [[ -n "$sid" ]] || sid="$(loginctl list-sessions --no-legend 2>/dev/null | awk -v u="$(id -un)" '$3==u{print $1; exit}')"
        if [[ -n "$sid" ]]; then
            [[ "$(loginctl show-session "$sid" -p LockedHint --value 2>/dev/null)" == "yes" ]] && return 0
        fi
    fi

    return 1
}

capture() {
    local target="$1"
    if command -v maim >/dev/null 2>&1; then
        maim "$target"
    elif command -v scrot >/dev/null 2>&1; then
        # -o: scrot refuses to overwrite the pre-existing mktemp placeholder otherwise.
        scrot -o "$target"
    elif command -v import >/dev/null 2>&1; then
        import -window root "$target"
    else
        echo "percy-screenshot: no screenshot tool found (install maim, scrot, or imagemagick)" >&2
        return 1
    fi
}

if is_locked; then
    exit 0
fi

tmpfile="$(mktemp --suffix=.png "$SCREENSHOT_DIR/.tmp-XXXXXX")"
trap 'rm -f "$tmpfile"' EXIT

capture "$tmpfile"

if [[ ! -s "$tmpfile" ]]; then
    echo "percy-screenshot: capture produced an empty file, discarding" >&2
    exit 1
fi

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
mv "$tmpfile" "$SCREENSHOT_DIR/screenshot_${timestamp}.png"

# Prune screenshots older than the retention window (set to 0 to disable).
if [[ "$RETENTION_DAYS" -gt 0 ]]; then
    find "$SCREENSHOT_DIR" -maxdepth 1 -name 'screenshot_*.png' -mtime "+${RETENTION_DAYS}" -delete
fi
