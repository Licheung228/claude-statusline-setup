[简体中文](./README_zh.md)

**base on claude code skill `/statusline`**

# claude-statusline-setup

A beautiful, informative statusline for Claude Code installed through `/statusline-setup`.

![statusline preview](https://img.shields.io/badge/left-model%20%C2%B7%20thinking%20%C2%B7%20effort-green?style=flat) ![right](https://img.shields.io/badge/right-ctx%3A72%25%2F28%25-blue?style=flat)

## What it does

Adds a real-time status bar to the bottom of your Claude Code terminal session:

```
Claude Sonnet 4.6 · thinking:on · high          ctx:72%/28%
```

- **Left side**: model name, thinking status, effort level
- **Right side**: context window usage with dynamic colors (green/yellow/red)
- Right-aligned to terminal width

## Install

1. Install this repository as a Claude Code skill:

   ```bash
   mkdir -p ~/.claude/skills/statusline-setup
   cp statusline-setup/SKILL.md ~/.claude/skills/statusline-setup/
   ```

2. In Claude Code, run one of these commands:

   ```
   /statusline-setup
   /statusline-setup --interactive
   /statusline-setup --preset
   ```

   - `/statusline-setup`: first asks whether to use the default preset or interactive setup
   - `/statusline-setup --interactive`: choose segments, layout, colors, and formatting interactively
   - `/statusline-setup --preset`: apply the default preset immediately

3. Restart Claude Code if prompted.

The skill handles platform detection, script generation, settings updates, and verification for you.

## Preview

| Context Usage | Color |
|---|---|
| < 50% | Green |
| 50-79% | Yellow |
| >= 80% | Red |

| Thinking | Color |
|---|---|
| Enabled | Green |
| Disabled | Dim |

## Notes

- On macOS / Linux, the skill will tell you if `jq` is missing.
- `/statusline-setup` now asks you to choose between the default preset and interactive setup first.
- The default mode applies a ready-to-use preset.
- Interactive mode lets you customize segments, layout, colors, and formatting.

## Available Segments

| Segment | Field | Description |
|---|---|---|
| `model` | `model.display_name` | Current model name |
| `thinking` | `thinking.enabled` | Thinking on/off |
| `effort` | `effort.level` | Effort level (low/medium/high/xhigh/max) |
| `ctx_used` | `context_window.used_percentage` | Context window used % |
| `ctx_remaining` | `context_window.remaining_percentage` | Context window remaining % |
| `ctx_combined` | both ctx fields | Combined `ctx:XX%/YY%` |
| `rate_5h` | `rate_limits.five_hour.used_percentage` | 5-hour rate limit % |
| `rate_7d` | `rate_limits.seven_day.used_percentage` | 7-day rate limit % |
| `session_name` | `session_name` | Session name (set by /rename) |
| `worktree` | `workspace.git_worktree` | Git worktree info |

## How It Works

Claude Code pipes a JSON payload to the statusline command on every assistant message. The script:

1. Reads JSON from stdin
2. Extracts fields
3. Applies colors and formatting
4. Calculates terminal width for right-alignment
5. Outputs a single formatted line

## Uninstall

### macOS / Linux

1. Delete `~/.claude/statusline-command.sh`.
2. Remove the `statusLine` field from `~/.claude/settings.json`.

### Windows

1. Delete `~/.claude/statusline-command.ps1`.
2. Remove the `statusLine` field from `~/.claude/settings.json`.

## License

[MIT](LICENSE)
