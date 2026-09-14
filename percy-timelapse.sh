#!/usr/bin/env bash
# Stitches a day's (or date range's) percy screenshots into a timelapse video.
set -euo pipefail

# shellcheck source=percy-common.sh
source "$(dirname "$(readlink -f "$0")")/percy-common.sh"
load_percy_config

SCREENSHOT_DIR="${PERCY_SCREENSHOT_DIR:-$HOME/Pictures/screenshots}"
FPS=24
DATE=""
FROM=""
TO=""
OUTPUT=""

usage() {
    cat >&2 <<'EOF'
Usage: percy-timelapse.sh [--date YYYY-MM-DD | --from YYYY-MM-DD --to YYYY-MM-DD]
                           [--fps N] [--output FILE]

Defaults to today if neither --date nor --from/--to is given.
FPS controls playback speed (frames of video per second), not capture rate.
EOF
}

is_date() { [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --date) DATE="${2:-}"; shift 2 ;;
        --from) FROM="${2:-}"; shift 2 ;;
        --to) TO="${2:-}"; shift 2 ;;
        --fps) FPS="${2:-}"; shift 2 ;;
        --output) OUTPUT="${2:-}"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        *) echo "error: unknown argument: $1" >&2; usage; exit 1 ;;
    esac
done

if [[ -n "$DATE" && ( -n "$FROM" || -n "$TO" ) ]]; then
    echo "error: use either --date, or --from/--to, not both" >&2
    exit 1
fi

if [[ -n "$DATE" ]]; then
    FROM="$DATE"
    TO="$DATE"
elif [[ -z "$FROM" && -z "$TO" ]]; then
    FROM="$(date +%Y-%m-%d)"
    TO="$FROM"
fi

for d in "$FROM" "$TO"; do
    is_date "$d" || { echo "error: invalid date '$d', expected YYYY-MM-DD" >&2; exit 1; }
done

if ! [[ "$FPS" =~ ^[0-9]+$ ]] || [[ "$FPS" -lt 1 ]]; then
    echo "error: --fps must be a positive integer, got: $FPS" >&2
    exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "error: ffmpeg not found (required for timelapse export)" >&2
    exit 1
fi

# Filenames are screenshot_YYYY-MM-DD_HH-MM-SS.png, so plain string
# comparison of the date portion sorts/filters correctly.
files=()
for f in "$SCREENSHOT_DIR"/screenshot_*.png; do
    [[ -e "$f" ]] || continue
    base="$(basename "$f")"
    day="${base#screenshot_}"
    day="${day%%_*}"
    if [[ ! "$day" < "$FROM" && ! "$day" > "$TO" ]]; then
        files+=("$f")
    fi
done

if [[ ${#files[@]} -eq 0 ]]; then
    echo "error: no screenshots found between $FROM and $TO in $SCREENSHOT_DIR" >&2
    exit 1
fi

OUTPUT="${OUTPUT:-$SCREENSHOT_DIR/timelapse_${FROM}_to_${TO}.mp4}"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir" "$OUTPUT.tmp.mp4"' EXIT

i=0
for f in "${files[@]}"; do
    printf -v idx "%06d" "$i"
    ln -s "$f" "$tmpdir/$idx.png"
    i=$((i + 1))
done

ffmpeg -y -framerate "$FPS" -i "$tmpdir/%06d.png" \
    -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -pix_fmt yuv420p \
    -c:v libx265 -crf 28 -preset medium -tag:v hvc1 "$OUTPUT.tmp.mp4"
# Atomic swap: a failed/interrupted encode never corrupts the previous file.
mv "$OUTPUT.tmp.mp4" "$OUTPUT"

echo "Wrote $OUTPUT (${#files[@]} frames @ ${FPS}fps, $FROM to $TO)"
