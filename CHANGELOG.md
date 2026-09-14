# Changelog / Decision Log

Running log of notable decisions and fixes made while developing percy.
Newest entries at the top.

## 2026-09-14

- **Configurable capture interval.** `install.sh` now takes `-i`/`--interval
  MINUTES` (default `1`) and templates `percy-screenshot.timer`'s
  `OnCalendar=*:0/N` from it instead of a hardcoded 1-minute value.
  `install.sh` always regenerates the timer unit and restarts it, so it's
  idempotent: re-running with a different `--interval` updates an
  already-installed service, and re-running with no flag resets it back to
  the 1-minute default. Verified `-i`, `--interval`, `--interval=N`, invalid
  input rejection, and that `list-timers` reflects the new schedule.

## Backlog (proposed, not yet approved)

Ideas for future work — require explicit go-ahead before implementing:

- **Privacy: skip/blur sensitive windows** — detect the focused window
  class (e.g. password managers, private-browsing profiles, video calls)
  via `xdotool`/`wmctrl` and skip the capture, similar to lock detection.
- **Pause during screen-sharing/calls** — detect common conferencing apps
  (Zoom, Meet/Chrome, Teams, OBS) and skip captures while one has focus or
  is running.
- **Multi-monitor support** — capture each connected monitor to its own
  file (via `maim`'s `-g`/xrandr geometry) instead of one combined image.
- **Config file** — support `~/.config/percy/config` (sourced shell vars)
  as an alternative to setting everything via `Environment=` in the
  service unit.
- **Timelapse export** — a helper script using `ffmpeg` to stitch a day's
  (or range's) screenshots into a timelapse video.
- **i3blocks extra actions** — right-click to open the screenshots folder
  or the most recent screenshot in an image viewer; middle-click to open
  the folder.
- **Toggle notifications** — `notify-send` feedback when the i3blocks
  double-click toggles the timer on/off, for confirmation beyond the color
  change.
- **Encryption at rest** — optionally encrypt saved screenshots (e.g. via
  `age` or `gocryptfs`) given they may capture sensitive on-screen data.

## 2026-09-14

- **Hardened `percy-screenshot.service` with systemd sandboxing.** Added
  `NoNewPrivileges`, `ProtectSystem=full`, `PrivateTmp`, `ProtectProc=invisible`,
  kernel/clock/hostname protections, restricted namespaces, locked
  personality, W^X memory, `AF_UNIX`-only sockets, an empty capability
  bounding set, `@system-service` syscall filter, and `UMask=0077`.
  `ProtectHome` is left off since screenshots are written under `$HOME`.
  Verified with `systemd-analyze security` (1.9 OK) and confirmed captures
  and `pgrep`-based lock detection still work under the sandbox.

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
