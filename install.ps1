# install.ps1 — Install the Context Manager skill for Claude Code (Windows)
# Usage: .\install.ps1

$ErrorActionPreference = "Stop"

$ClaudeDir    = "$env:USERPROFILE\.claude"
$SkillsDir    = "$ClaudeDir\skills"
$HooksDir     = "$ClaudeDir\hooks"
$ScriptsDir   = "$ClaudeDir\scripts"
$SettingsFile = "$ClaudeDir\settings.json"
$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Installing Context Manager..."

foreach ($dir in @($SkillsDir, $HooksDir, $ScriptsDir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
}

# ── Files ────────────────────────────────────────────────────────────────────
Copy-Item "$ScriptDir\context-manager.md"          "$SkillsDir\context-manager.md" -Force
Write-Host "  OK Skill:   $SkillsDir\context-manager.md"

Copy-Item "$ScriptDir\scripts\generate-map.py"     "$ScriptsDir\generate-map.py" -Force
Copy-Item "$ScriptDir\scripts\init-memory.py"      "$ScriptsDir\init-memory.py" -Force
Write-Host "  OK Scripts: generate-map.py, init-memory.py"

foreach ($hook in @("context-save-hook", "file-map-hook", "hallucination-guard-hook")) {
    Copy-Item "$ScriptDir\hooks\$hook.ps1" "$HooksDir\$hook.ps1" -Force
}
Write-Host "  OK Hooks:   context-save-hook, file-map-hook, hallucination-guard-hook"

# ── Register hooks in settings.json ─────────────────────────────────────────
function Register-Hook {
    param(
        [string]$HookType,
        [string]$HookCommand,
        [string]$HookName
    )

    $settings = if (Test-Path $SettingsFile) {
        try { Get-Content $SettingsFile -Raw | ConvertFrom-Json }
        catch { [pscustomobject]@{} }
    } else {
        [pscustomobject]@{}
    }

    if (-not $settings.PSObject.Properties["hooks"]) {
        $settings | Add-Member -MemberType NoteProperty -Name "hooks" -Value ([pscustomobject]@{})
    }
    if (-not $settings.hooks.PSObject.Properties[$HookType]) {
        $settings.hooks | Add-Member -MemberType NoteProperty -Name $HookType -Value @()
    }

    $existing = $settings.hooks.$HookType | Where-Object { ($_ | ConvertTo-Json -Depth 5) -match [regex]::Escape($HookName) }
    if ($existing) {
        Write-Host "  OK Already registered: $HookType -> $HookName"
        return
    }

    $newHook = [pscustomobject]@{
        hooks = @([pscustomobject]@{ type = "command"; command = $HookCommand })
    }
    $settings.hooks.$HookType = @($settings.hooks.$HookType) + $newHook
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
    Write-Host "  OK Registered: $HookType -> $HookName"
}

Register-Hook `
    -HookType "Stop" `
    -HookCommand "powershell -File `"$HooksDir\context-save-hook.ps1`"" `
    -HookName "context-save-hook"

Register-Hook `
    -HookType "PostToolUse" `
    -HookCommand "powershell -File `"$HooksDir\file-map-hook.ps1`"" `
    -HookName "file-map-hook"

Register-Hook `
    -HookType "PostToolUse" `
    -HookCommand "powershell -File `"$HooksDir\hallucination-guard-hook.ps1`"" `
    -HookName "hallucination-guard-hook"

# ── Pin subagents to cheapest model (Haiku) globally ─────────────────────────
$settings = if (Test-Path $SettingsFile) {
    try { Get-Content $SettingsFile -Raw | ConvertFrom-Json }
    catch { [pscustomobject]@{} }
} else {
    [pscustomobject]@{}
}

if (-not $settings.PSObject.Properties["env"]) {
    $settings | Add-Member -MemberType NoteProperty -Name "env" -Value ([pscustomobject]@{})
}
if (-not $settings.env.PSObject.Properties["CLAUDE_CODE_SUBAGENT_MODEL"]) {
    $settings.env | Add-Member -MemberType NoteProperty -Name "CLAUDE_CODE_SUBAGENT_MODEL" -Value "haiku"
} else {
    $settings.env.CLAUDE_CODE_SUBAGENT_MODEL = "haiku"
}
if (-not $settings.env.PSObject.Properties["CLAUDE_CODE_SUBAGENT_MODEL_FORCE"]) {
    $settings.env | Add-Member -MemberType NoteProperty -Name "CLAUDE_CODE_SUBAGENT_MODEL_FORCE" -Value "1"
} else {
    $settings.env.CLAUDE_CODE_SUBAGENT_MODEL_FORCE = "1"
}
$settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
Write-Host "  OK Subagents: pinned to claude-haiku (cheapest model, forced globally)"

Write-Host ""
Write-Host "Done."
Write-Host ""
Write-Host "Quick start:"
Write-Host "  1. Open any project in Claude Code"
Write-Host "  2. Run: /ctx init"
Write-Host "     -> Generates FILE_MAP.md (full annotated file tree)"
Write-Host "     -> Creates .claude\MEMORY\ (stack, decisions, APIs, patterns)"
Write-Host "     -> Injects CODING_RULES.md (no useless comments, no speculative code)"
Write-Host "     -> Wires everything into CLAUDE.md for auto-load"
Write-Host "  3. Run /ctx save before ending each session"
Write-Host "  4. Run /ctx share to hand off to another agent"
