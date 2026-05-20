---
name: statusline-setup
description: |
  Configure the Claude Code statusline display. By default, the skill first asks whether
  to use a clean preset or interactive customization. The preset uses model, thinking,
  effort on the left and ctx used/remaining on the right with dynamic colors. Interactive
  mode walks through segment selection, layout, colors, separators, and format.
  Cross-platform: bash on macOS/Linux, PowerShell on Windows.
  Use when asked to "setup statusline", "configure statusline", "statusline", or "customize status bar".
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - AskUserQuestion
triggers:
  - statusline setup
  - setup statusline
  - configure statusline
  - customize statusline
  - status bar
---

# Statusline Setup

Configure the Claude Code statusline. Reads JSON from Claude Code stdin and outputs a formatted status bar. Supports macOS/Linux (bash) and Windows (PowerShell).

## Mode Selection

Determine the mode from the user's argument first:

- `--preset` or `--default`: Default mode -- apply the preset immediately, no questions.
- `--interactive` or `-i`: Interactive mode -- walk through all choices.
- **No argument**: Ask first: "Use the default preset or interactive setup?"

If the user chooses default, continue with Default Mode.
If the user chooses interactive, continue with Interactive Mode.
If the argument is ambiguous, ask the same mode-selection question before proceeding.

## Platform Detection

Detect the user's platform:

```bash
uname -s
```

- `Darwin` or `Linux` → Unix mode (bash script)
- Other or Windows detected → PowerShell mode

If the result is not Darwin/Linux, use PowerShell mode. The two modes produce identical output but use different scripts.

---

## Default Mode (Preset)

Apply this preset directly. Do not ask any questions.

### Preset Layout

```
GLM 5.1 · thinking:on · high          ctx:72%/28%
```

- **Left side**: model (dim) | thinking:on/off (green when on, dim when off) | effort level (yellow, omitted when "medium")
- **Separator**: ` · ` (middle dot with spaces)
- **Right side**: `ctx:used%/remaining%` with dynamic colors
  - ctx_used: green <50%, yellow 50-79%, red >=80%
  - ctx_remaining: green >50%, yellow 20-50%, red <=20%
- **Right alignment**: right side pushed to far-right of terminal width

### Unix Steps (macOS / Linux)

#### Step 1: Check jq dependency

```bash
command -v jq >/dev/null 2>&1 || echo "MISSING_JQ"
```

If `MISSING_JQ`, tell the user: "jq is required. Install with `brew install jq` (macOS) or `sudo apt install jq` (Linux)." and stop.

#### Step 2: Write the statusline script

Write the following script to `~/.claude/statusline-command.sh`:

```bash
#!/bin/bash
# Status line: model · thinking · effort          ctx:used%/remaining%
input=$(cat)

reset='\033[0m'
dim='\033[2m'
model_col="${dim}"
thinking_on_col='\033[38;5;76m'
thinking_off_col="${dim}"
effort_col='\033[38;5;178m'

ctx_used_color() {
  local pct="$1"
  if [ "$pct" -lt 50 ] 2>/dev/null; then
    printf '\033[38;5;76m'
  elif [ "$pct" -lt 80 ] 2>/dev/null; then
    printf '\033[38;5;178m'
  else
    printf '\033[38;5;196m'
  fi
}

ctx_remaining_color() {
  local pct="$1"
  if [ "$pct" -gt 50 ] 2>/dev/null; then
    printf '\033[38;5;76m'
  elif [ "$pct" -gt 20 ] 2>/dev/null; then
    printf '\033[38;5;178m'
  else
    printf '\033[38;5;196m'
  fi
}

model=$(echo "$input" | jq -r 'if .model | type == "object" then .model.display_name // .model.id else .model end // empty')

thinking_enabled=$(echo "$input" | jq -r '.thinking.enabled // false')
if [ "$thinking_enabled" = "true" ]; then
  thinking_str="thinking:on"
  thinking_col="$thinking_on_col"
else
  thinking_str="thinking:off"
  thinking_col="$thinking_off_col"
fi

effort_level=$(echo "$input" | jq -r '.effort.level // empty')
effort_str=""
if [ -n "$effort_level" ] && [ "$effort_level" != "medium" ]; then
  effort_str="$effort_level"
fi

ctx_used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
ctx_used_str=""
ctx_used_col=""
if [ -n "$ctx_used_pct" ]; then
  ctx_used_rounded=$(printf "%.0f" "$ctx_used_pct")
  ctx_used_str="${ctx_used_rounded}%"
  ctx_used_col=$(ctx_used_color "$ctx_used_rounded")
fi

ctx_remaining_pct=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
if [ -z "$ctx_remaining_pct" ] && [ -n "$ctx_used_pct" ]; then
  ctx_remaining_pct=$(awk "BEGIN {printf \"%.0f\", 100 - $ctx_used_pct}")
fi
ctx_remaining_str=""
ctx_remaining_col=""
if [ -n "$ctx_remaining_pct" ]; then
  ctx_remaining_rounded=$(printf "%.0f" "$ctx_remaining_pct")
  ctx_remaining_str="${ctx_remaining_rounded}%"
  ctx_remaining_col=$(ctx_remaining_color "$ctx_remaining_rounded")
fi

left_parts=()
[ -n "$model" ] && left_parts+=("${model_col}${model}${reset}")
[ -n "$thinking_str" ] && left_parts+=("${thinking_col}${thinking_str}${reset}")
[ -n "$effort_str" ] && left_parts+=("${effort_col}${effort_str}${reset}")

left_plain=""
sep=" · "
first=true
for part in "${left_parts[@]}"; do
  if [ "$first" = true ]; then
    left_plain="$part"
    first=false
  else
    left_plain="${left_plain}${sep}${part}"
  fi
done

ctx_combined=""
if [ -n "$ctx_used_str" ] && [ -n "$ctx_remaining_str" ]; then
  ctx_combined="${dim}ctx:${reset}${ctx_used_col}${ctx_used_str}${reset}${dim}/${reset}${ctx_remaining_col}${ctx_remaining_str}${reset}"
elif [ -n "$ctx_used_str" ]; then
  ctx_combined="${dim}ctx:${reset}${ctx_used_col}${ctx_used_str}${reset}"
fi
right_plain="$ctx_combined"

strip_ansi() {
  local s="$1"
  printf '%s' "$s" | sed $'s/\033\[[0-9;]*m//g'
}

left_width=$(strip_ansi "$left_plain" | wc -m | tr -d ' ')
right_width=$(strip_ansi "$right_plain" | wc -m | tr -d ' ')
right_width=$((right_width + 0))

term_cols=$(tput cols 2>/dev/null || echo 120)

if [ -z "$right_plain" ]; then
  printf "%b" "$left_plain"
elif [ -z "$left_plain" ]; then
  padding=$((term_cols - right_width))
  [ "$padding" -lt 1 ] && padding=1
  printf "%*s%b" "$padding" "" "$right_plain"
else
  padding=$((term_cols - left_width - right_width))
  [ "$padding" -lt 2 ] && padding=2
  printf "%b%*s%b" "$left_plain" "$padding" "" "$right_plain"
fi
```

#### Step 3: Make script executable

```bash
chmod +x ~/.claude/statusline-command.sh
```

#### Step 4: Update settings.json

Read `~/.claude/settings.json`. Use the Edit tool to add or update the `statusLine` field:

```json
"statusLine": {
  "type": "command",
  "command": "bash $HOME/.claude/statusline-command.sh"
}
```

Use `$HOME` (not `~`) in the command path for portability. Preserve all other settings.

If `statusLine` already exists, update it. If not, add it. Be careful with JSON commas.

#### Step 5: Verify

Test the script:

```bash
echo '{"model":{"display_name":"Test Model"},"thinking":{"enabled":true},"effort":{"level":"high"},"context_window":{"used_percentage":72,"remaining_percentage":28}}' | bash ~/.claude/statusline-command.sh
```

Confirm the output looks correct: `Test Model · thinking:on · high` on the left, `ctx:72%/28%` on the right.

### Windows Steps (PowerShell)

No jq dependency — PowerShell uses native `ConvertFrom-Json`.

#### Step 1: Write the statusline script

Write the following script to `~/.claude/statusline-command.ps1`:

```powershell
$inputJson = [Console]::In.ReadToEnd()
$data = $inputJson | ConvertFrom-Json

$ESC = [char]27
$reset = "$ESC[0m"
$dim   = "$ESC[2m"

$model = ""
if ($data.model -is [PSCustomObject]) {
    $model = if ($data.model.display_name) { $data.model.display_name } elseif ($data.model.id) { $data.model.id } else { "" }
} elseif ($data.model) {
    $model = $data.model.ToString()
}
$modelCol = $dim

$thinkingEnabled = $data.thinking.enabled -eq $true
if ($thinkingEnabled) {
    $thinkingStr = "thinking:on"
    $thinkingCol = "$ESC[38;5;76m"
} else {
    $thinkingStr = "thinking:off"
    $thinkingCol = $dim
}

$effortLevel = ""
if ($data.effort.level) { $effortLevel = $data.effort.level.ToString() }
$effortStr = ""
$effortCol = "$ESC[38;5;178m"
if ($effortLevel -and $effortLevel -ne "medium") {
    $effortStr = $effortLevel
}

function Get-UsedColor([int]$pct) {
    if ($pct -lt 50) { "$ESC[38;5;76m" }
    elseif ($pct -lt 80) { "$ESC[38;5;178m" }
    else { "$ESC[38;5;196m" }
}

function Get-RemainingColor([int]$pct) {
    if ($pct -gt 50) { "$ESC[38;5;76m" }
    elseif ($pct -gt 20) { "$ESC[38;5;178m" }
    else { "$ESC[38;5;196m" }
}

$ctxUsedStr = ""
$ctxUsedCol = ""
$ctxUsedPct = $null
if ($data.context_window.used_percentage -ne $null) {
    $ctxUsedPct = [math]::Round([double]$data.context_window.used_percentage)
    $ctxUsedStr = "$ctxUsedPct%"
    $ctxUsedCol = Get-UsedColor $ctxUsedPct
}

$ctxRemainingStr = ""
$ctxRemainingCol = ""
if ($data.context_window.remaining_percentage -ne $null) {
    $ctxRemPct = [math]::Round([double]$data.context_window.remaining_percentage)
    $ctxRemainingStr = "$ctxRemPct%"
    $ctxRemainingCol = Get-RemainingColor $ctxRemPct
} elseif ($null -ne $ctxUsedPct) {
    $ctxRemPct = 100 - $ctxUsedPct
    $ctxRemainingStr = "$ctxRemPct%"
    $ctxRemainingCol = Get-RemainingColor $ctxRemPct
}

$leftParts = @()
if ($model) { $leftParts += "${modelCol}${model}${reset}" }
if ($thinkingStr) { $leftParts += "${thinkingCol}${thinkingStr}${reset}" }
if ($effortStr) { $leftParts += "${effortCol}${effortStr}${reset}" }
$leftPlain = $leftParts -join " · "

$rightPlain = ""
if ($ctxUsedStr -and $ctxRemainingStr) {
    $rightPlain = "${dim}ctx:${reset}${ctxUsedCol}${ctxUsedStr}${reset}${dim}/${reset}${ctxRemainingCol}${ctxRemainingStr}${reset}"
} elseif ($ctxUsedStr) {
    $rightPlain = "${dim}ctx:${reset}${ctxUsedCol}${ctxUsedStr}${reset}"
}

function Strip-Ansi([string]$s) {
    $s -replace '\x1b\[[0-9;]*m', ''
}

$leftWidth = (Strip-Ansi $leftPlain).Length
$rightWidth = (Strip-Ansi $rightPlain).Length
$termCols = [Console]::WindowWidth
if (-not $termCols -or $termCols -lt 1) { $termCols = 120 }

if (-not $rightPlain) {
    Write-Host -NoNewline $leftPlain
} elseif (-not $leftPlain) {
    $padding = [Math]::Max(1, $termCols - $rightWidth)
    Write-Host -NoNewline (" " * $padding) $rightPlain
} else {
    $padding = [Math]::Max(2, $termCols - $leftWidth - $rightWidth)
    Write-Host -NoNewline $leftPlain (" " * $padding) $rightPlain
}
```

#### Step 2: Update settings.json

Read `~/.claude/settings.json`. Use the Edit tool to add or update the `statusLine` field:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -File $HOME/.claude/statusline-command.ps1"
}
```

Preserve all other settings. Be careful with JSON commas.

#### Step 3: Verify

Test the script:

```powershell
echo '{"model":{"display_name":"Test Model"},"thinking":{"enabled":true},"effort":{"level":"high"},"context_window":{"used_percentage":72,"remaining_percentage":28}}' | powershell -NoProfile -File ~/.claude/statusline-command.ps1
```

### Confirm (both platforms)

Tell the user:
- Statusline script written to `~/.claude/statusline-command.sh` (Unix) or `~/.claude/statusline-command.ps1` (Windows)
- settings.json updated
- Restart Claude Code (exit and re-enter) for changes to take effect
- Show a preview of the expected layout: `model · thinking:on · high          ctx:72%/28%`

---

## Interactive Mode

Walk through each choice sequentially using AskUserQuestion. Use the answers to generate a custom script.

### Question 1: Segments

Which segments should appear in your statusline?

Available segments (from Claude Code's statusline JSON input):

| Segment | Source field | Description |
|---------|-------------|-------------|
| model | `model.display_name` or `model.id` | Current model name |
| thinking | `thinking.enabled` | Thinking status (on/off) |
| effort | `effort.level` | Effort level (low/medium/high/xhigh/max) |
| ctx_used | `context_window.used_percentage` | Context window used % |
| ctx_remaining | `context_window.remaining_percentage` | Context window remaining % |
| ctx_combined | both ctx fields | Combined ctx: used%/remaining% |
| rate_5h | `rate_limits.five_hour.used_percentage` | 5-hour rate limit usage % |
| rate_7d | `rate_limits.seven_day.used_percentage` | 7-day rate limit usage % |
| session_name | `session_name` | Session name (set by /rename) |
| worktree | `workspace.git_worktree` or `worktree` | Git worktree info |

Note: `ctx_combined` and `ctx_used`/`ctx_remaining` are mutually exclusive. If the user picks `ctx_combined`, skip `ctx_used` and `ctx_remaining`.

Default selection: model, thinking, effort, ctx_combined

### Question 2: Layout

For each selected segment, assign it to the left side or right side.

Left side segments are left-aligned. Right side segments are right-aligned (pushed to far right of terminal).

Default: model, thinking, effort on left; ctx_combined on right.

### Question 3: Order

What order should segments appear within each side?

Default: left = [model, thinking, effort], right = [ctx_combined]

### Question 4: Separator

What character separates segments on the same side?

Present these options:
- ` · ` -- middle dot (compact, structured)
- ` | ` -- pipe (classic)
- ` / ` -- slash
- ` — ` -- em dash
- Custom -- user types their preferred separator

### Question 5: Segment format

How should each selected segment be formatted?

Present per-segment options based on what was selected:

- **model**: full name (`Claude 3.5 Sonnet`) or short name (`sonnet`)
- **thinking**: `thinking:on/off` | `think:on/off` | `on/off` | `+/-`
- **effort**: full word (`high`) | first letter (`H`) | only show when not default
- **ctx_combined**: `ctx:72%/28%` | `72%/28%` | `ctx 72%/28%`
- **ctx_used**: `72%` | `used:72%`
- **ctx_remaining**: `28%` | `rem:28%`
- **rate_5h**: `5h:50%` | `50%`
- **rate_7d**: `7d:30%` | `30%`
- **session_name**: as-is
- **worktree**: branch name only | `wt:branch`

### Question 6: Colors

For each segment, choose a color:

**Static color options**: dim (dimmed gray), green (76), yellow (178), red (196), cyan (87), blue (69), magenta (163), bold/white, none (terminal default)

**Dynamic color** (for percentage segments only): color changes based on value thresholds. If chosen, ask for green/yellow/red threshold boundaries.

Defaults:
- model: dim
- thinking on: green, off: dim
- effort: yellow
- ctx_used: dynamic (green <50%, yellow 50-79%, red >=80%)
- ctx_remaining: dynamic (green >50%, yellow 20-50%, red <=20%)
- rate_5h / rate_7d: dynamic (green <50%, yellow 50-79%, red >=80%)
- session_name: dim
- worktree: cyan

### Question 7: Effort visibility

Should "medium" effort level be shown or hidden?

Default: hidden (only show when level is not "medium" and not empty).

### Step 8: Platform-specific check

**Unix**: Check jq dependency:

```bash
command -v jq >/dev/null 2>&1 || echo "MISSING_JQ"
```

If `MISSING_JQ`, tell the user: "jq is required. Install with `brew install jq` (macOS) or `sudo apt install jq` (Linux)." and stop.

**Windows**: No dependency check needed (PowerShell native JSON).

### Step 9: Generate script

Using all answers, generate the script for the user's platform.

**Unix (bash)** — same structure as the preset bash script but with the user's chosen configuration. The script must:

1. Start with `#!/bin/bash` and read stdin: `input=$(cat)`
2. Define `reset` and `dim` ANSI codes at the top
3. Define color variables for each segment (static or dynamic threshold functions)
4. Extract each selected field using `jq -r` with `// empty` or `// false` fallbacks
5. Apply the chosen format to each segment
6. Apply chosen colors
7. Build left side array with chosen separator, skip empty segments
8. Build right side array with chosen separator, skip empty segments
9. Define `strip_ansi()` function
10. Calculate ANSI-stripped widths for right-alignment
11. Compose final output: left + padding + right, with minimum 2 spaces padding

**Windows (PowerShell)** — same structure as the preset PowerShell script but with the user's chosen configuration. The script must:

1. Read stdin: `$inputJson = [Console]::In.ReadToEnd()` then `$data = $inputJson | ConvertFrom-Json`
2. Define `$ESC = [char]27`, `$reset`, `$dim` ANSI codes at the top
3. Define color variables for each segment (static or dynamic threshold functions)
4. Extract each selected field from `$data` with null checks
5. Apply the chosen format to each segment
6. Apply chosen colors
7. Build left side array, join with chosen separator, skip empty segments
8. Build right side string, skip empty segments
9. Define `Strip-Ansi` function using `-replace '\x1b\[[0-9;]*m', ''`
10. Calculate widths for right-alignment using `[Console]::WindowWidth`
11. Compose final output with `Write-Host -NoNewline`

**Dynamic color function pattern** (bash, for percentage-based segments):

```bash
segment_name_color() {
  local pct="$1"
  if [ "$pct" -lt GREEN_YELLOW_THRESHOLD ] 2>/dev/null; then
    printf '\033[38;5;76m'    # green
  elif [ "$pct" -lt YELLOW_RED_THRESHOLD ] 2>/dev/null; then
    printf '\033[38;5;178m'   # yellow
  else
    printf '\033[38;5;196m'   # red
  fi
}
```

**Dynamic color function pattern** (PowerShell):

```powershell
function Get-SegmentNameColor([int]$pct) {
    if ($pct -lt GREEN_YELLOW_THRESHOLD) { "$ESC[38;5;76m" }
    elseif ($pct -lt YELLOW_RED_THRESHOLD) { "$ESC[38;5;178m" }
    else { "$ESC[38;5;196m" }
}
```

**Special cases** (both platforms):
- If `ctx_remaining` is missing but `ctx_used` exists, compute as `100 - used`
- `ctx_combined` format: `${dim}ctx:${reset}${used_col}${used}%${reset}${dim}/${reset}${rem_col}${rem}%${reset}`
- `effort` hidden when medium

### Step 10: Write files

**Unix**:
1. Write generated script to `~/.claude/statusline-command.sh`
2. `chmod +x ~/.claude/statusline-command.sh`
3. Read `~/.claude/settings.json`, use Edit tool to add or update:

```json
"statusLine": {
  "type": "command",
  "command": "bash $HOME/.claude/statusline-command.sh"
}
```

**Windows**:
1. Write generated script to `~/.claude/statusline-command.ps1`
2. Read `~/.claude/settings.json`, use Edit tool to add or update:

```json
"statusLine": {
  "type": "command",
  "command": "powershell -NoProfile -File $HOME/.claude/statusline-command.ps1"
}
```

Use `$HOME` not `~`. Preserve all other settings.

### Step 11: Verify

Test the script with a sample JSON payload. Construct one that includes all the segments the user selected.

**Unix**: `echo '<sample JSON>' | bash ~/.claude/statusline-command.sh`
**Windows**: `echo '<sample JSON>' | powershell -NoProfile -File ~/.claude/statusline-command.ps1`

### Step 12: Confirm

Tell the user:
- Statusline script written to `~/.claude/statusline-command.sh` (Unix) or `~/.claude/statusline-command.ps1` (Windows)
- settings.json updated
- Restart Claude Code (exit and re-enter) for changes to take effect
- Show a preview of their configured layout

---

## Script Generation Rules

When generating the statusline script, follow these rules:

### Bash (Unix)

1. **Always `#!/bin/bash`** and `input=$(cat)`
2. **Always define `reset='\033[0m'` and `dim='\033[2m'`** at the top
3. **Use `jq -r`** for all field extraction with `// empty` or `// false` fallbacks
4. **Dynamic color comparisons** use `2>/dev/null` to handle non-numeric gracefully
5. **Right-alignment math**: `padding = term_cols - left_width - right_width`, minimum 2
6. **`strip_ansi()`** using `sed $'s/\033\[[0-9;]*m//g'` for width calculation
7. **Fallback for missing `remaining_percentage`**: compute as `100 - used_percentage` via awk
8. **settings.json path**: use `$HOME` not `~`
9. **Missing fields**: skip segments whose fields are empty/missing (do not render empty strings)
10. **`ctx_combined` is a single right-side segment**: it renders as `ctx:XX%/YY%`, not two separate segments joined by separator

### PowerShell (Windows)

1. **Always** `$inputJson = [Console]::In.ReadToEnd()` then `$data = $inputJson | ConvertFrom-Json`
2. **Always define** `$ESC = [char]27`, `$reset = "$ESC[0m"`, `$dim = "$ESC[2m"` at the top
3. **Use native property access** on `$data` with null checks (`-ne $null`, `?` operator)
4. **Dynamic color functions** use `[int]` type cast for numeric comparisons
5. **Right-alignment**: `$padding = [Math]::Max(2, $termCols - $leftWidth - $rightWidth)`
6. **`Strip-Ansi`** using `-replace '\x1b\[[0-9;]*m', ''` for width calculation
7. **Fallback for missing `remaining_percentage`**: compute as `100 - used`
8. **settings.json path**: use `$HOME` not `~`
9. **Missing fields**: skip segments whose fields are empty/missing
10. **`ctx_combined` is a single right-side segment**: it renders as `ctx:XX%/YY%`, not two separate segments joined by separator
11. **Use `Write-Host -NoNewline`** for output (no trailing newline)
