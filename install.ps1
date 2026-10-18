param(
    [ValidateSet("Claude", "Codex", "All")]
    [string]$Target = "Claude"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ClaudeDir = "$env:USERPROFILE\.claude"
$CodexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { "$env:USERPROFILE\.codex" }

function Install-Codex {
    $skillDir = Join-Path $CodexDir "skills\context-manager"
    $scriptsDir = Join-Path $skillDir "scripts"
    New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
    Copy-Item "$ScriptDir\context-manager.md" "$skillDir\SKILL.md" -Force
    foreach ($script in @("generate-map.py", "init-memory.py", "init-context.py")) {
        Copy-Item "$ScriptDir\scripts\$script" "$scriptsDir\$script" -Force
    }
    Write-Host "  OK Codex skill: $skillDir\SKILL.md"
    Write-Host "  OK Codex scripts: generate-map.py, init-memory.py, init-context.py"
}

function Register-ClaudeHook {
    param([string]$HookType, [string]$HookCommand, [string]$HookName, [string]$SettingsFile)

    $settings = if (Test-Path $SettingsFile) {
        try { Get-Content $SettingsFile -Raw | ConvertFrom-Json } catch { [pscustomobject]@{} }
    } else { [pscustomobject]@{} }
    if (-not $settings.PSObject.Properties["hooks"]) {
        $settings | Add-Member NoteProperty "hooks" ([pscustomobject]@{})
    }
    if (-not $settings.hooks.PSObject.Properties[$HookType]) {
        $settings.hooks | Add-Member NoteProperty $HookType @()
    }
    $existing = $settings.hooks.$HookType | Where-Object { ($_ | ConvertTo-Json -Depth 5) -match [regex]::Escape($HookName) }
    if (-not $existing) {
        $entry = [pscustomobject]@{ hooks = @([pscustomobject]@{ type = "command"; command = $HookCommand }) }
        $settings.hooks.$HookType = @($settings.hooks.$HookType) + $entry
    }
    $settings | ConvertTo-Json -Depth 10 | Set-Content $SettingsFile -Encoding UTF8
}

function Install-Claude {
    $skillsDir = "$ClaudeDir\skills"
    $hooksDir = "$ClaudeDir\hooks"
    $scriptsDir = "$ClaudeDir\scripts"
    $settingsFile = "$ClaudeDir\settings.json"
    foreach ($dir in @($skillsDir, $hooksDir, $scriptsDir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    Copy-Item "$ScriptDir\context-manager.md" "$skillsDir\context-manager.md" -Force
    foreach ($script in @("generate-map.py", "init-memory.py", "init-context.py")) {
        Copy-Item "$ScriptDir\scripts\$script" "$scriptsDir\$script" -Force
    }
    foreach ($hook in @("context-save-hook", "file-map-hook", "hallucination-guard-hook")) {
        Copy-Item "$ScriptDir\hooks\$hook.ps1" "$hooksDir\$hook.ps1" -Force
    }
    Register-ClaudeHook "Stop" "powershell -File `"$hooksDir\context-save-hook.ps1`"" "context-save-hook" $settingsFile
    Register-ClaudeHook "PostToolUse" "powershell -File `"$hooksDir\file-map-hook.ps1`"" "file-map-hook" $settingsFile
    Register-ClaudeHook "PostToolUse" "powershell -File `"$hooksDir\hallucination-guard-hook.ps1`"" "hallucination-guard-hook" $settingsFile

    $settings = if (Test-Path $settingsFile) {
        try { Get-Content $settingsFile -Raw | ConvertFrom-Json } catch { [pscustomobject]@{} }
    } else { [pscustomobject]@{} }
    if (-not $settings.PSObject.Properties["env"]) {
        $settings | Add-Member NoteProperty "env" ([pscustomobject]@{})
    }
    $settings.env | Add-Member NoteProperty "CLAUDE_CODE_SUBAGENT_MODEL" "haiku" -Force
    $settings.env | Add-Member NoteProperty "CLAUDE_CODE_SUBAGENT_MODEL_FORCE" "1" -Force
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile -Encoding UTF8
    Write-Host "  OK Claude skill, scripts, hooks, and Haiku pin installed"
}

Write-Host "Installing Context Manager ($Target)..."
if ($Target -eq "Codex" -or $Target -eq "All") { Install-Codex }
if ($Target -eq "Claude" -or $Target -eq "All") { Install-Claude }
Write-Host ""
Write-Host "Done."
if ($Target -eq "Codex" -or $Target -eq "All") {
    Write-Host "Codex: restart Codex, then ask it to use `$context-manager."
    Write-Host "Direct initialization: python `"$CodexDir\skills\context-manager\scripts\init-context.py`" <project-root> --host codex"
}
if ($Target -eq "Claude" -or $Target -eq "All") {
    Write-Host "Claude Code: open a project and run /ctx init."
}