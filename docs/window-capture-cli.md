# screencog Window Capture CLI

`screencog` is a macOS command-line tool for targeted window screenshots using native APIs.

## Examples

```bash
screencog list --json
screencog capture --app "Safari" --output /tmp/safari.png
screencog capture --window-title "CIQ Simulator - Instinct" --output /tmp/iq.png
screencog capture --window-id 12345 --format jpg --quality 85 --output /tmp/window.jpg
screencog capture --app "Xcode" --crop 100,80,1200,700 --output /tmp/xcode-crop.png --result-json
screencog capture --app "Connect IQ Device Simulator" --window-title "CIQ Simulator" --click 360,520 --output /tmp/after-click.png
screencog input --window-id 12345 --click 220,140
screencog input --app "ChatGPT" --type "hello from screencog"
screencog input --app "WhatsApp" --scroll 0,-5
screencog permissions --json --prompt
```

## Capture flow

1. Enumerates windows with `CGWindowListCopyWindowInfo`.
2. Resolves target by selectors: `--window-id`, `--app`, `--window-title`, `--pid`, `--bundle-id`.
3. Uses a scoring heuristic for `--app` selection to avoid auxiliary untitled windows when better titled candidates exist.
4. Captures with ScreenCaptureKit (`SCScreenshotManager`) first.
5. Falls back to `CGWindowListCreateImage` if needed.
6. If target is likely offscreen/minimized, temporarily activates that app, retries capture, then restores prior frontmost app.

## Permissions

Capture requires Screen Recording permission.
Input simulation requires Accessibility permission.

- `System Settings` -> `Privacy & Security` -> `Screen Recording`
- `System Settings` -> `Privacy & Security` -> `Accessibility`
- Grant access to the built `screencog` binary (or terminal host process).

Use `--no-permission-prompt` to fail without showing a permission request.

## Focus and Space behavior

`screencog` first tries a non-intrusive capture path that does not change focus.
For windows that are not directly renderable, it may briefly activate the target app to force rendering, then reactivate the previous frontmost app.
For input commands, app activation is expected. `screencog` restores frontmost app and window minimize/hidden state by default.
For deterministic state restore across input + capture, prefer a single `capture` command with a pre-input action (`--click/--type/--scroll`) so one shared focus snapshot is used.
By default, `screencog` also attempts private SkyLight Space snapshot/restore. If unavailable, it falls back to app/window restore only.
When private APIs are available, `screencog` also snapshots the top window on the target Space before bringing the target forward, then restores that top window ordering.

## Listing output

- Default `--list` output is tab-delimited for terminal readability.
- `--list --json` returns structured JSON (id, owner, title, PID, bounds, visibility, and renderability hints).
- `--list` can be combined with `--app` and/or `--window-title` to filter the results.

## High-value options

- `--wait-for-window <seconds>`: wait for target window to appear.
- `--retry-interval-ms <ms>`: polling interval while waiting.
- `--result-json`: emit structured JSON for capture/input results.
- `--restore-debug-json`: include before/after runtime snapshots (frontmost app/window + active Space info) for restore debugging.
- `--crop x,y,w,h`: crop captured image.
- `--format png|jpg` and `--quality 1-100`: control output encoding.
- `--no-private-space-restore`: disable private Space restore and use fallback behavior only.
- `--no-restore-hard-reattach`: disable exact-window hard reattach fallback.
- `--no-restore-space-nudge`: disable Ctrl+Arrow space nudge fallback.
- `--restore-force-window-id <id>`: force restore target window identity.
