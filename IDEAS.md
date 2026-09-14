# Ideas (parked, not scheduled)

Reasonable ideas that aren't being actively worked toward — pulled out of
the active backlog in CHANGELOG.md so they don't clutter it, but worth
revisiting later.

- **Privacy: skip/blur sensitive windows** — detect the focused window
  class (e.g. password managers, private-browsing profiles, video calls)
  via `xdotool`/`wmctrl` and skip the capture, similar to lock detection.
- **Pause during screen-sharing/calls** — detect common conferencing apps
  (Zoom, Meet/Chrome, Teams, OBS) and skip captures while one has focus or
  is running.
