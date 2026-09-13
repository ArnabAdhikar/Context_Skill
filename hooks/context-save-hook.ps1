# context-save-hook.ps1
# Claude Code Stop hook for Windows — reminds Claude to save context at session end.
# Place in: %USERPROFILE%\.claude\hooks\context-save-hook.ps1
# Register in: %USERPROFILE%\.claude\settings.json under hooks.Stop

$input_data = $input | Out-String | ConvertFrom-Json -ErrorAction SilentlyContinue
if (-not $input_data) { exit 0 }

$eventType = $input_data.hook_event_name
if ($eventType -ne "Stop") { exit 0 }

# Check if inside a git repo
$gitRoot = git rev-parse --show-toplevel 2>$null
if (-not $gitRoot) { exit 0 }

$contextFile = Join-Path $gitRoot ".claude\CONTEXT.md"
$today = Get-Date -Format "yyyy-MM-dd"

if (Test-Path $contextFile) {
    $lastUpdated = (Get-Content $contextFile | Select-String "last_updated:" | Select-Object -First 1) -replace ".*last_updated:\s*", ""
    if ($lastUpdated -ne $today) {
        Write-Output "CONTEXT REMINDER: Project context was last updated on $lastUpdated. Consider running ``/ctx save`` to capture today's work before ending the session."
    }
} else {
    Write-Output "CONTEXT REMINDER: No .claude/CONTEXT.md found in this project. Run ``/ctx init`` to start tracking context."
}

exit 0
