# percy

**Per**iodically **C**apturing **Y**ourself

**Automatically captures a screenshot of your display every minute** via a
`systemd --user` timer, with an i3blocks indicator to see the status and
toggle it on/off.

## Prerequisites

- Linux with `systemd --user` support (enabled by default on most distros).
- i3 (or another X11 window manager) with an active X session.
- i3blocks, if you want the status/toggle indicator in your bar.
- One screenshot tool available on `$PATH`: [`maim`](https://github.com/naelstrof/maim) (preferred), `scrot`, or ImageMagick's `import`.
- `ffmpeg`, *optional* — only needed for [timelapse export](#timelapse-export).

Install a screenshot tool, e.g. on Debian/Ubuntu:

```sh
sudo apt install maim
```

or Arch:

```sh
sudo pacman -S maim
```

## Install

From this directory:

```sh
./install.sh
```

Captures every minute by default. Use `-i`/`--interval` to change how often
(in minutes):

```sh
./install.sh --interval 5   # every 5 minutes
```

`install.sh` is idempotent — re-run it any time (e.g. with a different
`--interval`) to update an already-installed service; omitting the flag
resets the interval back to the 1-minute default.

This will:

- Copy `percy-screenshot.sh` and `percy-screenshot-ctl.sh` to `~/.local/bin`.
- Copy `percy-screenshot.service` and `percy-screenshot.timer` to `~/.config/systemd/user`.
- Reload the systemd user daemon and `enable --now` the timer, so screenshots
  start immediately and the timer survives reboots.

Screenshots are saved to `~/Pictures/screenshots` by default. Override with
the `PERCY_SCREENSHOT_DIR` environment variable (set it in
`percy-screenshot.service` under `[Service]` as `Environment=PERCY_SCREENSHOT_DIR=...`
if you want it to apply to the timed runs). Screenshots older than 7 days are
pruned automatically; override with `PERCY_SCREENSHOT_RETENTION_DAYS` (set to
`0` to disable pruning).

### Config file

Instead of editing `Environment=` lines in the systemd units, you can copy
`~/.config/percy/config.example` (installed alongside everything else) to
`~/.config/percy/config` and set `PERCY_*` variables there — it's sourced by
all the scripts. Precedence is `Environment=`/shell env var > config file >
built-in default, so an explicitly-set environment variable always wins;
the config file only fills in values that aren't already set. It's sourced
as shell code, so treat its permissions like `~/.bashrc`.

If your X session doesn't use `DISPLAY=:0` or the default `~/.Xauthority`,
edit `~/.config/systemd/user/percy-screenshot.service` after installing and
adjust the `Environment=` lines, then run `systemctl --user daemon-reload`.

### Skipping screenshots while locked

The capture is skipped entirely (no file written) if the session appears
locked, controlled via `Environment=` in `percy-screenshot.service`:

- **Lock detection** (`PERCY_LOCK_DETECT=1`): checks whether a screen locker
  process is running (`i3lock`, `light-locker`, `xflock4`, `slock`,
  `xtrlock`, `xsecurelock`, `betterlockscreen` by default — override with
  `PERCY_LOCKER_PROCESSES="foo bar"`), or whether `loginctl` reports the
  session's `LockedHint` as locked.

Set `PERCY_LOCK_DETECT=0` to disable it.

### Add the i3blocks indicator

Add the block from [i3blocks.conf](i3blocks.conf) to your i3blocks config
(usually `~/.config/i3blocks/config`):

```ini
[percy-screenshot]
command=$HOME/.local/bin/percy-screenshot-ctl.sh block
interval=5
markup=none
```

Then reload i3 (`$mod+Shift+r`) or restart i3blocks.

## Usage

- The timer runs `percy-screenshot.sh` every minute automatically once installed.
- The i3blocks indicator shows 📷 on/off with green/red text depending on
  whether the timer is active.
- **Double-click** the indicator to toggle the timer on or off.
- **Right-click** the indicator to open the screenshots folder.
- A single click just refreshes the displayed status.

You can also control it from a terminal with `percy-screenshot-ctl.sh`:

```sh
percy-screenshot-ctl.sh status    # prints "on" or "off"
percy-screenshot-ctl.sh enable    # turn the timer on (systemctl --user enable --now)
percy-screenshot-ctl.sh disable   # turn the timer off (systemctl --user disable --now)
percy-screenshot-ctl.sh toggle    # flip the current state
percy-screenshot-ctl.sh open-folder # open the screenshots folder
```

Or use `systemctl` directly:

```sh
systemctl --user status percy-screenshot.timer
journalctl --user -u percy-screenshot.service -e   # view capture logs/errors
```

### Timelapse export

Stitch a day's (or a date range's) screenshots into a video with `ffmpeg`
(install it separately — it's only needed for this script):

```sh
percy-timelapse.sh                                   # today, default 24fps
percy-timelapse.sh --date 2026-09-14                 # a specific day
percy-timelapse.sh --from 2026-09-01 --to 2026-09-07 # a date range
percy-timelapse.sh --fps 10 --output ~/Videos/out.mp4
```

`--fps` controls playback speed (how many captured frames play per second of
video), not the original capture rate. Output defaults to
`timelapse_<from>_to_<to>.mp4` inside the screenshots directory, encoded as
H.265 (`.mp4`, `hvc1` tag for player compatibility).

If `ffmpeg` was installed at install-time, `percy-timelapse.timer` regenerates
**today's** timelapse every hour on the hour, overwriting the same
`timelapse_<today>_to_<today>.mp4` in place (the write is atomic, so an
interrupted run never corrupts the existing file). If you install `ffmpeg`
after running `install.sh`, just re-run `install.sh` to pick it up, or enable
manually: `systemctl --user enable --now percy-timelapse.timer`.

## Uninstall

```sh
./uninstall.sh
```

This stops and disables the timer, and removes the installed scripts and
systemd unit files. It does not delete your captured screenshots or
automatically remove the block from your i3blocks config — remove that entry
manually if you added it.
