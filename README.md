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
- ImageMagick (`compare`/`identify`), *optional* — only needed for idle detection (see below). The feature silently disables itself if these aren't installed.

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

If your X session doesn't use `DISPLAY=:0` or the default `~/.Xauthority`,
edit `~/.config/systemd/user/percy-screenshot.service` after installing and
adjust the `Environment=` lines, then run `systemctl --user daemon-reload`.

### Skipping idle screenshots

Two mechanisms avoid piling up pointless screenshots when you're not
actually using the machine, both on by default and configurable via
`Environment=` in `percy-screenshot.service`:

- **Lock detection** (`PERCY_LOCK_DETECT=1`): skips the capture entirely if a
  screen locker process is running (checks `i3lock`, `light-locker`,
  `xflock4`, `slock`, `xtrlock`, `xsecurelock`, `betterlockscreen` by
  default — override with `PERCY_LOCKER_PROCESSES="foo bar"`), or if
  `loginctl` reports the session's `LockedHint` as locked.
- **Idle/duplicate detection** (`PERCY_IDLE_DETECT=1`): after capturing,
  compares the new screenshot against the last one kept using ImageMagick's
  `compare`. If fewer than `PERCY_DIFF_THRESHOLD_PERCENT` percent of pixels
  differ (default `0.5`, with a `PERCY_DIFF_FUZZ` color tolerance of `5%` to
  ignore compression/anti-aliasing noise), the new screenshot is discarded as
  a near-identical duplicate (e.g. only a statusbar clock changed). Requires
  `compare`/`identify` from ImageMagick; if they're not installed, every
  screenshot is kept.

Set either variable to `0` to disable it.

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
- A single click just refreshes the displayed status.

You can also control it from a terminal with `percy-screenshot-ctl.sh`:

```sh
percy-screenshot-ctl.sh status    # prints "on" or "off"
percy-screenshot-ctl.sh enable    # turn the timer on (systemctl --user enable --now)
percy-screenshot-ctl.sh disable   # turn the timer off (systemctl --user disable --now)
percy-screenshot-ctl.sh toggle    # flip the current state
```

Or use `systemctl` directly:

```sh
systemctl --user status percy-screenshot.timer
journalctl --user -u percy-screenshot.service -e   # view capture logs/errors
```

## Uninstall

```sh
./uninstall.sh
```

This stops and disables the timer, and removes the installed scripts and
systemd unit files. It does not delete your captured screenshots or
automatically remove the block from your i3blocks config — remove that entry
manually if you added it.
