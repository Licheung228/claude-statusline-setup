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
