#!/usr/bin/env bash
# Captures a screenshot of the current display to $PERCY_SCREENSHOT_DIR,
# skipping the capture while the session is locked or (optionally) when the
# new screenshot is nearly identical to the last one kept (idle detection).
set -euo pipefail

SCREENSHOT_DIR="${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
RETENTION_DAYS="${PERCY_SCREENSHOT_RETENTION_DAYS:-7}"
LOCK_DETECT="${PERCY_LOCK_DETECT:-1}"
LOCKER_PROCESSES="${PERCY_LOCKER_PROCESSES:-i3lock light-locker xflock4 slock xtrlock xsecurelock betterlockscreen}"
IDLE_DETECT="${PERCY_IDLE_DETECT:-1}"
DIFF_THRESHOLD_PERCENT="${PERCY_DIFF_THRESHOLD_PERCENT:-0.5}"
DIFF_FUZZ="${PERCY_DIFF_FUZZ:-5%}"

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

# True if $2 is a near-duplicate of $1 (e.g. only a statusbar clock changed),
# based on the percentage of differing pixels. Requires ImageMagick.
is_idle_duplicate() {
    local prev="$1" new="$2"
    command -v compare >/dev/null 2>&1 || return 1
    command -v identify >/dev/null 2>&1 || return 1

    local diff_pixels w h total
    diff_pixels="$(compare -metric AE -fuzz "$DIFF_FUZZ" "$prev" "$new" null: 2>&1)" || true
    # -fuzz makes AE report a float (e.g. "57798.3"), not always an integer.
    [[ "$diff_pixels" =~ ^[0-9]+(\.[0-9]+)?$ ]] || return 1

    read -r w h < <(identify -format "%w %h" "$new" 2>/dev/null) || return 1
    total=$(( w * h ))
    (( total > 0 )) || return 1

    awk -v d="$diff_pixels" -v t="$total" -v thr="$DIFF_THRESHOLD_PERCENT" \
        'BEGIN { exit !((d / t * 100) < thr) }'
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

if [[ "$IDLE_DETECT" == "1" ]]; then
    prev="$(find "$SCREENSHOT_DIR" -maxdepth 1 -name 'screenshot_*.png' | sort | tail -n1)"
    if [[ -n "$prev" ]] && is_idle_duplicate "$prev" "$tmpfile"; then
        exit 0
    fi
fi

timestamp="$(date +%Y-%m-%d_%H-%M-%S)"
mv "$tmpfile" "$SCREENSHOT_DIR/screenshot_${timestamp}.png"

# Prune screenshots older than the retention window (set to 0 to disable).
if [[ "$RETENTION_DAYS" -gt 0 ]]; then
    find "$SCREENSHOT_DIR" -maxdepth 1 -name 'screenshot_*.png' -mtime "+${RETENTION_DAYS}" -delete
fi
