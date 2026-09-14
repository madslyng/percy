# Changelog / Decision Log

Running log of notable decisions and fixes made while developing percy.
Newest entries at the top.

## 2026-09-14

- **Fixed timer never re-firing.** `percy-screenshot.timer` used
  `OnBootSec`/`OnUnitActiveSec` (monotonic timers). After being
  restarted/reinstalled a few times, `systemctl --user show` reported
  `NextElapseUSecMonotonic=infinity` and the timer stopped rescheduling
  entirely (only a manual `systemctl --user start` would fire it). Switched
  to `OnCalendar=*:0/1` (absolute wall-clock scheduling), which doesn't have
  this failure mode. Verified it self-triggers every minute without manual
  intervention.

- **Removed idle/similarity duplicate-detection filter.** It compared each
  new screenshot against the last kept one (via ImageMagick `compare -fuzz`)
  and discarded near-identical captures. In practice the threshold was too
  aggressive and screenshots stopped being taken. Removed the feature
  entirely (`is_idle_duplicate`, `PERCY_IDLE_DETECT`, `PERCY_DIFF_*` env
  vars) and kept only lock detection. Every capture is now saved
  unconditionally unless the session is locked.

- **Fixed scrot overwrite bug.** The script pre-creates the destination file
  via `mktemp` before capturing. `scrot` refuses to overwrite an existing
  (even empty) file by default and silently wrote to a different filename
  (`*_000.png`) instead, leaving a corrupt 0-byte "screenshot" and an
  orphaned temp file. Fixed with `scrot -o`, and added a check that discards
  the capture if the resulting file is empty.

- **(Reverted) idle-detection float regex bug.** While the idle-detection
  feature was still in place, found that ImageMagick's `compare -metric AE`
  returns a float when `-fuzz` is used (e.g. `57798.3`), but the discard
  logic used an integer-only regex, so the feature silently never triggered.
  Fixed at the time, then the whole feature was removed per above once it
  proved too aggressive even after the fix.

## Design decisions

- **`systemd --user` over system-wide units**: no root required, ties
  lifecycle to the user session, simplest to install/uninstall per-user.
- **Screenshot tool fallback order**: `maim` > `scrot` > `import`
  (ImageMagick) — prefers lightweight, purpose-built X11 screenshot tools
  first, falls back to the more heavyweight but near-universally-available
  ImageMagick.
- **Lock detection** via known locker process names (`i3lock`, etc.) plus a
  `loginctl` `LockedHint` fallback, since there's no single universal way to
  detect "screen locked" across setups.
- **i3blocks double-click toggle**: i3blocks has no native double-click
  concept, so it's implemented via a debounce state file recording the last
  click timestamp; two left-clicks within 400ms count as a double-click.
- **Capture-to-tempfile-then-rename**: screenshots are captured to a
  `mktemp` temp file first and atomically `mv`'d into place, so a
  crash/interruption mid-capture never leaves a half-written file under the
  final `screenshot_*.png` name.
