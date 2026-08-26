# ======================================================================
# Vantrilex - Claude Code Orchestrator (Multi-Provider Launcher)
# ======================================================================
# One interactive launcher for Claude Code across providers. No secrets
# are stored in this file: keys are read from the environment, from a
# gitignored .env.vantrilex sidecar, or asked for at runtime (with an
# opt-in save for next time).
#
# Run:  powershell -ExecutionPolicy Bypass -File vantrilex.ps1
# ======================================================================

$host.UI.RawUI.WindowTitle = 'Vantrilex - Claude Code Orchestrator'

# Terminal encoding: Arabic + box-drawing glyphs without mojibake.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$EnvFile = Join-Path (Get-Location).Path '.env.vantrilex'

function Show-Logo {
    Clear-Host
    $logoLines = @(
        "    ██╗   ██╗ █████╗ ███╗   ██╗████████╗██████╗ ██╗██╗     ███████╗██╗  ██╗",
        "    ██║   ██║██╔══██╗████╗  ██║╚══██╔══╝██╔══██╗██║██║     ██╔════╝╚██╗██╔╝",
        "    ██║   ██║███████║██╔██╗ ██║   ██║   ██████╔╝██║██║     █████╗   ╚███╔╝ ",
        "    ╚██╗ ██╔╝██╔══██║██║╚██╗██║   ██║   ██╔══██╗██║██║     ██╔══╝   ██╔██╗ ",
        "     ╚████╔╝ ██║  ██║██║ ╚████║   ██║   ██║  ██║██║███████╗███████╗██╔╝ ██╗",
        "      ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝╚══════╝╚═╝  ╚═╝"
    )
    for ($i = 0; $i -lt $logoLines.Count; $i++) {
        if ($i % 2 -eq 0) { Write-Host $logoLines[$i] -ForegroundColor Cyan }
        else { Write-Host $logoLines[$i] -ForegroundColor White }
    }
    Write-Host ''
    Write-Host '              ───  ' -NoNewline -ForegroundColor Yellow
    Write-Host 'Vantrilex' -NoNewline -ForegroundColor Blue
    Write-Host '  ───  Claude Code Orchestrator' -ForegroundColor Yellow
    Write-Host '======================================================================' -ForegroundColor White
    Write-Host ''
    Write-Host '🔑  Connected to: Multi-Provider Gateway (DeepSeek / OpenRouter / Orca / Custom)' -ForegroundColor Green
    Write-Host ''
}

function Read-SavedValue {
    param([string]$Name)
    if (-not (Test-Path $EnvFile)) { return $null }
    foreach ($line in Get-Content $EnvFile) {
        if ($line -match "^$Name=(.*)$") { return $Matches[1].Trim() }
    }
    return $null
}

function Save-SavedValue {
    param([string]$Name, [string]$Value)
    $existing = @()
    if (Test-Path $EnvFile) { $existing = @(Get-Content $EnvFile | Where-Object { $_ -notmatch "^$Name=" }) }
    $existing += "$Name=$Value"
    Set-Content -Path $EnvFile -Value $existing -Encoding UTF8
}

function Get-Credential-Value {
    # Get-Credential-Value <ENV_VAR_NAME> [<prompt label>]
    # Resolution order: process env -> .env.vantrilex -> interactive paste
    # with opt-in save. Only the last 6 chars are ever displayed.
    param([string]$Name, [string]$Label)

    $val = [Environment]::GetEnvironmentVariable($Name, 'Process')
    $src = 'environment'
    if (-not $val) { $val = Read-SavedValue $Name; $src = '.env.vantrilex' }
    if ($val) {
        Write-Host ('  using {0} from {1} (...{2})' -f $Name, $src, $val.Substring([Math]::Max(0, $val.Length - 6))) -ForegroundColor DarkGray
        return $val
    }

    Write-Host ('  Enter {0} ({1}): ' -f $Name, $Label) -NoNewline -ForegroundColor Yellow
    $val = Read-Host
    if ([string]::IsNullOrWhiteSpace($val)) { return $null }
    $save = Read-Host '  Save to .env.vantrilex (gitignored) for next time? (y/N)'
    if ($save -eq 'y' -or $save -eq 'Y') { Save-SavedValue $Name $val }
    return $val
}

function Show-Menu {
    param([string]$Title, [string]$Color)
    Write-Host ('┌{0}┐' -f ('─' * 58)) -ForegroundColor $Color
    Write-Host ('│  {0}' -f $Title.PadRight(56)) -ForegroundColor $Color
    Write-Host ('└{0}┘' -f ('─' * 58)) -ForegroundColor $Color
    Write-Host ''
}

function Option-Line {
    param([string]$Key, [string]$Text, [string]$Hint)
    Write-Host (" [{0}] " -f $Key) -NoNewline -ForegroundColor Cyan
    Write-Host $Text -NoNewline -ForegroundColor White
    if ($Hint) { Write-Host ('  ' + $Hint) -ForegroundColor Gray } else { Write-Host '' }
}

# ======================================================================
# Provider / model selection
# ======================================================================

Show-Logo

do {
    Show-Menu 'Select the provider to run Claude Code with' 'Yellow'
    Option-Line '1' 'DeepSeek V4 Pro'       '(Direct API - High Reliability)'
    Option-Line '2' 'DeepSeek V4 Flash'     '(Direct API - Fastest)'
    Option-Line '3' 'OrcaRouter (Free)'     '(Gateway, 90+ free providers)'
    Option-Line '4' 'Ox Alpha (OpenRouter)' '(1M Context)'
    Option-Line 'C' 'Custom endpoint'       '(any OpenAI-compatible base URL + model)'
    Option-Line 'X' 'Exit'
    Write-Host ''
    $choice = Read-Host '➤  Enter your choice (1/2/3/4/C/X)'
    if ($choice -eq 'X' -or $choice -eq 'x') { Write-Host 'Goodbye!' -ForegroundColor Green; exit }
    if ($choice -in '1','2','3','4','C','c') { break }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
    Write-Host ''
} while ($true)

$model = ''; $label = ''

switch ($choice.ToLower()) {
    '1' {
        $key = Get-Credential-Value 'DEEPSEEK_API_KEY' 'paste your DeepSeek key'
        if (-not $key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }
        $model = 'DeepSeek V4 Pro'; $label = 'deepseek-chat'
        $env:ANTHROPIC_BASE_URL = 'https://api.deepseek.com/anthropic'
        $env:ANTHROPIC_AUTH_TOKEN = $key
        $env:ANTHROPIC_MODEL = $label
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $label
    }
    '2' {
        $key = Get-Credential-Value 'DEEPSEEK_API_KEY' 'paste your DeepSeek key'
        if (-not $key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }
        $model = 'DeepSeek V4 Flash'; $label = 'deepseek-chat'
        $env:ANTHROPIC_BASE_URL = 'https://api.deepseek.com/anthropic'
        $env:ANTHROPIC_AUTH_TOKEN = $key
        $env:ANTHROPIC_MODEL = $label
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $label
    }
    '3' {
        $key = Get-Credential-Value 'ORCA_API_KEY' 'paste your Orca gateway key'
        if (-not $key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }
        $model = 'OrcaRouter (Free Gateway)'; $label = 'deepseek/deepseek-chat'
        $env:ANTHROPIC_BASE_URL = 'https://api.orcarouter.ai'
        $env:ANTHROPIC_AUTH_TOKEN = $key
        $env:ANTHROPIC_MODEL = $label
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $label
    }
    '4' {
        $key = Get-Credential-Value 'OPENROUTER_API_KEY' 'paste your OpenRouter key (sk-or-v1-...)'
        if (-not $key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }
        $model = 'Ox Alpha'; $label = 'stealth/ox-alpha'
        $env:ANTHROPIC_BASE_URL = 'https://openrouter.ai/api'
        $env:ANTHROPIC_AUTH_TOKEN = $key
        $env:ANTHROPIC_MODEL = $label
        $env:ANTHROPIC_SMALL_FAST_MODEL = $label
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $label
        $env:CLAUDE_CODE_MAX_CONTEXT_TOKENS = '1000000'
        $env:CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT = '1'
    }
    'c' {
        $model = 'Custom endpoint'
        $env:ANTHROPIC_BASE_URL = (Read-Host '➤  Base URL (e.g. https://host/api)')
        if (-not $env:ANTHROPIC_BASE_URL) { Write-Host 'Base URL required.' -ForegroundColor Red; exit }
        $label = Read-Host '➤  Model id (e.g. vendor/model-name)'
        if (-not $label) { Write-Host 'Model id required.' -ForegroundColor Red; exit }
        $key = Get-Credential-Value 'CUSTOM_API_KEY' 'paste the endpoint API key'
        if (-not $key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }
        $env:ANTHROPIC_AUTH_TOKEN = $key
        $env:ANTHROPIC_MODEL = $label
        $env:CLAUDE_CODE_SUBAGENT_MODEL = $label
    }
}

# ======================================================================
# Effort level
# ======================================================================

Clear-Host
Show-Logo

do {
    Show-Menu 'Select Effort Level' 'Blue'
    Option-Line '1' 'Low'       '- Fastest responses, lower token usage'
    Option-Line '2' 'Medium'    '- Balanced speed and quality'
    Option-Line '3' 'High'      '- High quality, deeper reasoning'
    Option-Line '4' 'XHigh'     '- Extra deep reasoning'
    Option-Line '5' 'Max'       '- Maximum reasoning quality'
    Option-Line '6' 'Ultracode' '- Multi-agent dynamic workflow orchestration'
    Option-Line 'B' 'Back'      '- Return to provider menu'
    Write-Host ''
    $effort = Read-Host '➤  Enter the level number (1-6/B)'
    if ($effort -eq 'B' -or $effort -eq 'b') {
        & $MyInvocation.MyCommand.Path
        exit
    }
    if ($effort -match '^[1-6]$') {
        $effortMap = @{ '1'='low'; '2'='medium'; '3'='high'; '4'='xhigh'; '5'='max'; '6'='ultracode' }
        $env:CLAUDE_CODE_EFFORT_LEVEL = $effortMap[$effort]
        break
    }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
} while ($true)

# ======================================================================
# Project path
# ======================================================================

Clear-Host
Show-Logo

Show-Menu 'Enter your project path' 'Green'
Write-Host 'Example: C:\Projects\Git-hub\my-project' -ForegroundColor White
Write-Host '(Leave empty to use the current directory)' -ForegroundColor White
Write-Host ''
$projectPath = Read-Host '➤  Path'
if ($projectPath -eq '') { $projectPath = (Get-Location).Path }
if (-not (Test-Path $projectPath)) {
    Write-Host '⚠  Path does not exist. Create it? (Y/N)' -ForegroundColor Yellow
    $create = Read-Host '➤  '
    if ($create -eq 'Y' -or $create -eq 'y') {
        New-Item -Path $projectPath -ItemType Directory -Force | Out-Null
        Write-Host '✓  Folder created.' -ForegroundColor Green
    } else {
        Write-Host 'Aborted.' -ForegroundColor Red
        exit
    }
}

# ======================================================================
# Summary and launch
# ======================================================================

Clear-Host
Show-Logo

Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '                      🚀  Ready to Launch  🚀' -ForegroundColor White
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Model'        -NoNewline -ForegroundColor White; Write-Host '        : ' -NoNewline; Write-Host $model -ForegroundColor Cyan
Write-Host 'Effort Level' -NoNewline -ForegroundColor White; Write-Host ' : ' -NoNewline; Write-Host $env:CLAUDE_CODE_EFFORT_LEVEL -ForegroundColor Yellow
Write-Host 'Path'         -NoNewline -ForegroundColor White; Write-Host '         : ' -NoNewline; Write-Host $projectPath -ForegroundColor White
Write-Host ''
Write-Host 'Press Enter to launch Claude Code...' -ForegroundColor Green
Read-Host | Out-Null

Set-Location $projectPath
Write-Host 'Launching Claude Code with ' -NoNewline; Write-Host $model -ForegroundColor Cyan
Write-Host ''
npx @anthropic-ai/claude-code@latest
