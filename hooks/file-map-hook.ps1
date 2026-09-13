# file-map-hook.ps1 — PostToolUse hook (Windows)
# Regenerates .claude/FILE_MAP.md after any file-writing tool call.

$ErrorActionPreference = "SilentlyContinue"

$raw = $input | Out-String
try { $data = $raw | ConvertFrom-Json } catch { exit 0 }

$toolName = $data.tool_name
if ($toolName -notin @("Write", "Edit", "Bash")) { exit 0 }

# For Bash tool: skip read-only commands
if ($toolName -eq "Bash") {
    $cmd = $data.tool_input.command
    $writePatterns = @('mkdir','touch','mv ','cp ','rm ','rmdir','>','>>','tee ','install ','npm ','yarn ','pip ','cargo ','go get','git add','git commit','git checkout','git merge','git rebase','git reset')
    $isWrite = $writePatterns | Where-Object { $cmd -match [regex]::Escape($_) }
    if (-not $isWrite) { exit 0 }
}

# Find project root
$gitRoot = git rev-parse --show-toplevel 2>$null
$projectRoot = if ($gitRoot) { $gitRoot } else { Get-Location }

$contextFile = Join-Path $projectRoot ".claude\CONTEXT.md"
if (-not (Test-Path $contextFile)) { exit 0 }

$script = "$env:USERPROFILE\.claude\scripts\generate-map.py"
$mapFile = Join-Path $projectRoot ".claude\FILE_MAP.md"

if (-not (Test-Path $script)) { exit 0 }

# Regenerate in background — don't block the tool response
# Use array form to correctly handle paths containing spaces
Start-Process python3 -ArgumentList @($script, $projectRoot, '--output', $mapFile) -WindowStyle Hidden -NoNewWindow

exit 0
