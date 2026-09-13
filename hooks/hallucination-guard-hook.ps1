# hallucination-guard-hook.ps1 — PostToolUse hook (Windows)
# Detects consecutive tool failures and triggers auto-compact on threshold.

$ErrorActionPreference = "SilentlyContinue"

$COUNTER_FILE = "$env:TEMP\.claude_failure_count"
$THRESHOLD = 3

$raw = $input | Out-String
try { $data = $raw | ConvertFrom-Json } catch { exit 0 }

$toolName = $data.tool_name
if ($toolName -notin @("Read", "Edit", "Write", "Bash")) { exit 0 }

# Extract response text
$response = ""
try {
    $r = $data.tool_response
    if ($r -is [string]) { $response = $r }
    elseif ($r.output) { $response = $r.output }
    elseif ($r.error) { $response = $r.error }
} catch {}

# Detect failure signals
$failurePatterns = @(
    'does not exist',
    'no such file',
    'not found',
    'cannot find',
    'file not found',
    'ENOENT',
    'cannot open',
    'command not found',
    'is not recognized',
    'unknown command',
    'String to replace not found',
    'old_string not found',
    'pattern not found'
)

$isFailure = $false
foreach ($pattern in $failurePatterns) {
    if ($response -imatch [regex]::Escape($pattern)) {
        $isFailure = $true
        break
    }
}

# Permission denied is not hallucination
if ($response -imatch 'permission denied|access denied') { exit 0 }

if ($isFailure) {
    $count = 1
    if (Test-Path $COUNTER_FILE) {
        try { $count = [int](Get-Content $COUNTER_FILE -Raw) + 1 } catch { $count = 1 }
    }
    Set-Content $COUNTER_FILE $count

    if ($count -ge $THRESHOLD) {
        Set-Content $COUNTER_FILE 0
        Write-Output @"
CONTEXT MANAGER: Auto-compact triggered.

The agent has encountered $THRESHOLD consecutive tool failures, which typically indicates
context drift or hallucination (referencing files/code that do not exist).

Running /compact now to reset context while preserving key information.
Please re-read FILE_MAP.md and CONTEXT.md before continuing.

/compact
"@
    }
} else {
    Set-Content $COUNTER_FILE 0
}

exit 0
