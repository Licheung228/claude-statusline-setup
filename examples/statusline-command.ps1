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
