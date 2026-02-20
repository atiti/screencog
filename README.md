# screencog

[![Release](https://img.shields.io/github/v/release/atiti/screencog)](https://github.com/atiti/screencog/releases)
[![Release Binaries](https://img.shields.io/github/actions/workflow/status/atiti/screencog/release-binaries.yml?label=release%20binaries)](https://github.com/atiti/screencog/actions/workflows/release-binaries.yml)
[![License](https://img.shields.io/github/license/atiti/screencog)](./LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2015%2B-black)](https://www.apple.com/macos/)

Blazing-fast macOS window capture and input automation for agents and power users.

`screencog` can capture specific app windows by ID/name, including background windows and windows on other Spaces, while attempting to restore your original app/window/Space state.

## Features

- Target by `--window-id`, `--app`, `--window-title`, `--pid`, or `--bundle-id`
- Window screenshots to file or stdout
- Input automation: click, double-click, right-click, type, scroll
- Chrome tab-aware targeting with `--tab-title`, `--tab-url`, `--tab-index`, `--chrome-profile`
- JSON output for list/capture/input flows
- Restore controls tuned for non-disruptive automation
- Native macOS APIs (ScreenCaptureKit + CoreGraphics fallback)

## Install

### Option 1: one-command install/update (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/atiti/screencog/main/scripts/install.sh | bash
```

Re-run the same command any time to update to the latest release.

### Option 2: Homebrew tap (prep included)

```bash
brew tap atiti/screencog
brew install screencog
```

Homebrew formula prep and release update flow: `docs/homebrew.md`

### Option 3: build from source

```bash
swift build -c release
./.build/release/screencog --help
```

## Quick examples

```bash
# list windows
screencog list --json

# capture by app
screencog capture --app "ChatGPT" --output /tmp/chatgpt.png

# capture by window id
screencog capture --window-id 12345 --output /tmp/window.png --result-json

# click then capture in one pass (shared restore snapshot)
screencog capture --app "Connect IQ Device Simulator" --click 360,520 --output /tmp/after-click.png

# input-only command
screencog input --app "Ghostty" --type "hello from screencog" --result-json

# Chrome tab targeting
screencog capture \
  --app "Google Chrome" \
  --chrome-profile "attila@markster.ai" \
  --tab-title "event-scout-web" \
  --output /tmp/event-scout-web.png

# permission diagnostics
screencog permissions --json --prompt
```

## Permissions

- Screen capture requires `Screen Recording` permission.
- Input automation requires `Accessibility` permission.

Use:

```bash
screencog permissions --json --prompt
```

to validate and trigger prompts.

## Restore behavior

- Default mode tries to restore your prior app/window/Space state.
- Strict restore parity is opt-in with `--restore-strict`.
- Use `--no-restore-state` for maximum speed when restore is not needed.

## Documentation

- CLI usage: `docs/window-capture-cli.md`
- Homebrew prep and release bump flow: `docs/homebrew.md`
- Codex/LLM skill: `skills/screencog/SKILL.md`

## Release assets

Tagging `v*` runs `.github/workflows/release-binaries.yml` and publishes:

- `screencog-macos-arm64`
- `screencog-macos-x86_64`
- `screencog-macos-universal`
- `checksums.txt`
