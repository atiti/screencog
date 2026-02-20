# screencog skill

Use this skill when the user needs deterministic macOS window screenshots or input automation from an LLM agent.

## What this skill provides

- Window discovery by app/title/window id
- Screenshot capture for background or cross-Space windows
- Input automation (click/type/scroll) with restore-aware behavior
- JSON output for machine-readable automation

## Preconditions

- macOS with Screen Recording permission granted for the running host app (terminal/agent runtime).
- Accessibility permission granted when input automation is required.

## Command patterns

### 1) Discover candidate windows

```bash
screencog list --json
screencog list --json --app "Google Chrome"
```

### 2) Capture a specific window

```bash
screencog capture --window-id <id> --output /tmp/shot.png --result-json
```

### 3) Capture by app + title

```bash
screencog capture --app "Connect IQ Device Simulator" --window-title "CIQ Simulator" --output /tmp/ciq.png --result-json
```

### 4) Input + capture in one pass (preferred for stable restore)

```bash
screencog capture --app "Connect IQ Device Simulator" --click 360,520 --output /tmp/after-click.png --result-json
```

### 5) Chrome tab targeting

```bash
screencog list --tabs --json --app "Google Chrome"
screencog capture --app "Google Chrome" --chrome-profile "attila@markster.ai" --tab-title "event-scout-web" --output /tmp/tab.png --result-json
```

## Operational guidance for LLM agents

- Prefer `--window-id` after discovery for deterministic behavior.
- Use `--result-json` in automation flows.
- Use one combined `capture` command with pre-input action when possible.
- If restore is not required, use `--no-restore-state` for fastest execution.
- If stricter restore parity checks are needed, add `--restore-strict`.

## Failure handling

- Permission errors: run `screencog permissions --json --prompt`.
- Missing target: re-run `list --json` and re-resolve selectors.
- Background rendering issues: retry with app/title selectors and keep restore enabled.
