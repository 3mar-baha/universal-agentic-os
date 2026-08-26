# ======================================================================
# Vantrilex - Claude Code Orchestrator (Multi-Provider Session Launcher)
# ======================================================================
# One interactive entry point that:
#   1. Asks what kind of prompt you want BEFORE anything else:
#        [1] No prompt      - just open Claude Code
#        [2] Have full docs - inject the Master Initial Project Prompt
#                             (ingests and validates your documentation,
#                             zero overwriting, starts Phase 2 TDD)
#        [3] Custom idea    - grill-me style Socratic interview about your
#                             idea, then author the COMPLETE documentation
#                             suite, then follow the governed workflow
#   2. Selects the provider (keys resolved env -> .env.vantrilex -> paste;
#      never stored in this file) and the effort level.
#   3. Prepares the target project: provisions the 6 toolkits if missing,
#      vendors the OS runtime (hooks, scripts, meta-skill, .mcp.json) when
#      absent so MCP, skills, and hooks load directly into the session.
#   4. Launches Claude Code with the chosen prompt pre-loaded as the first
#      message of the session.
#
# Run:  powershell -ExecutionPolicy Bypass -File vantrilex.ps1
# ======================================================================

$host.UI.RawUI.WindowTitle = 'Vantrilex - Claude Code Orchestrator'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot = $PSScriptRoot
$EnvFile = Join-Path (Get-Location).Path '.env.vantrilex'
$ToolkitDir = $env:CLAUDE_TOOLKIT_DIR
if (-not $ToolkitDir) { $ToolkitDir = Join-Path $env:USERPROFILE 'ai-agent-toolkit' }

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
    Write-Host '🔑  Multi-Provider Gateway (DeepSeek / OpenRouter / Orca / Custom)' -ForegroundColor Green
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
    # Resolution order: process env -> .env.vantrilex -> paste (opt-in save).
    # Only the last 6 characters of any key are ever displayed.
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
# Prompt construction
# ======================================================================

function Get-MasterPrompt {
    # Extract the fenced master-prompt block from docs/05-INITIAL-PROMPT.md
    # so there is a single source of truth. Falls back to a condensed form.
    $doc = Join-Path $RepoRoot 'docs/05-INITIAL-PROMPT.md'
    if (Test-Path $doc) {
        $raw = Get-Content -Raw -Encoding UTF8 $doc
        $m = [regex]::Match($raw, '(?s)```\r?\n(.+?)```')
        if ($m.Success -and $m.Groups[1].Value.Trim().Length -gt 200) {
            return $m.Groups[1].Value.Trim()
        }
    }
    return @"
You are the autonomous engineering agent of the Universal Agentic Engineering OS. This repository carries its governing documentation. Execute in order, zero confirmation prompts:
1. Adopt the tripartite model (Leader/Guide/Implementer); read CLAUDE.md, skills/universal-agentic-workflow.md, docs/10-CHECKPOINT.md.
2. Verify the 6-toolkits: bash scripts/setup-toolkit.sh --verify (provision if missing).
3. Ingest every document under docs/ READ-ONLY (bash scripts/uos.sh ingest); stop and report broken references, never overwrite specs.
4. Wire machinery (.claude/hooks, scripts, git hooks, uos CLI); fix every doctor FAIL.
5. Generate a project-tailored CLAUDE.md only if absent or stub.
6. Anchor docs/10-CHECKPOINT.md: status ACTIVE, ACTIVE_PHASE per reality, milestone DAG.
7. Begin Phase 2 (Core Build & TDD) immediately: orchestrate-stage 2, dispatch worktrees, red-green-refactor, integrate via merge gates.
Hold all nine invariants; zero AI attribution anywhere.
"@
}

function Get-CustomIdeaPrompt {
    return @"
You are the Guide and autonomous engineering agent of the Universal Agentic Engineering OS. My idea follows at the end. Run this exact sequence, zero confirmation prompts except where answers are required from me:
1. Adopt the tripartite model; read CLAUDE.md (if present), skills/universal-agentic-workflow.md, docs/10-CHECKPOINT.md (if present). Verify toolkits: bash scripts/setup-toolkit.sh --verify.
2. GRILL MY IDEA (grill-me discipline): interview me ONE question per message, waiting for each answer - at least 8 questions covering: mission in one sentence, target users, domain archetype (Software Engineering / AI-ML / Business Automation / Deep Research), success criteria, hard constraints, the deployment path (cloud/on-prem/container/serverless/desktop/CI-only), integration surface, and what we deliberately will NOT build. Challenge weak assumptions instead of accepting them; propose the sharper alternative when my answer is vague.
3. Close discovery by restating the mission in <=3 sentences and getting my explicit confirmation.
4. AUTHOR THE COMPLETE DOCUMENTATION SUITE (no stubs, no filler): the canonical hierarchy - CLAUDE.md (project-tailored constitution), README.md, .gitignore, .env.example, LICENSE, CONTRIBUTING.md, CHANGELOG.md, docs/00-VISION.md, docs/01-ARCHITECTURE.md, docs/02-BACKLOG.md, docs/03-DECISIONS.md (open it with the discovery trade-offs), docs/04-RUNBOOK.md, docs/05-TEST-PLAN.md, SECURITY.md, Makefile, .github/workflows/ci.yml - plus docs/10-CHECKPOINT.md anchored: status ACTIVE, ACTIVE_PHASE 2, milestone DAG decomposed from the confirmed mission. Initialize git and commit the scaffold.
5. BEGIN PHASE 2 (Core Build & TDD): orchestrate phase kit, dispatch workstreams into isolated worktrees, strict red-green-refactor cycles, integrate only through the merge gates. Phases advance on Guide sign-off only.
Hold all nine invariants throughout; tests are the contract; zero AI attribution anywhere.

--- MY IDEA ---
"@
}

# ======================================================================
# Session preparation
# ======================================================================

function Ensure-Toolkits {
    # Provision the 6 upstream toolkits once so skills resolve in-session.
    $marker = Join-Path $ToolkitDir 'everything-claude-code'
    if (Test-Path $marker) {
        Write-Host '✓  toolkits present' -ForegroundColor Green
        return
    }
    Write-Host '⋯  provisioning the 6 toolkits (first run only)...' -ForegroundColor Yellow
    $setup = Join-Path $RepoRoot 'scripts/setup-toolkit.sh'
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        & bash $setup
        if ($LASTEXITCODE -eq 0) { Write-Host '✓  toolkits provisioned' -ForegroundColor Green }
        else { Write-Host '⚠  toolkit provisioning failed; sessions will lack injected skills' -ForegroundColor Red }
    } else {
        Write-Host '⚠  bash not found; run scripts/setup-toolkit.sh manually' -ForegroundColor Red
    }
}

function Install-OsRuntime {
    # Vendor the OS runtime into a project that lacks it: native hooks +
    # settings (session lifecycle), lifecycle scripts, the Universal
    # Meta-Skill, the pinned .mcp.json, and lint config. MCP servers,
    # skills, and hooks then load directly into every session there.
    param([string]$ProjectPath)

    if (Test-Path (Join-Path $ProjectPath '.claude/hooks/session_start.sh')) {
        Write-Host '✓  OS runtime already installed in project' -ForegroundColor Green
        return
    }
    $ans = Read-Host '➤  Install the OS runtime into this project (hooks, skills, MCP, scripts)? (Y/n)'
    if ($ans -eq 'n' -or $ans -eq 'N') { return }

    $dst = $ProjectPath
    New-Item -ItemType Directory -Force -Path `
        (Join-Path $dst 'scripts'), (Join-Path $dst 'skills'), `
        (Join-Path $dst '.claude/hooks'), (Join-Path $dst '.githooks'), `
        (Join-Path $dst '.github/workflows') | Out-Null

    Copy-Item (Join-Path $RepoRoot 'scripts/*.sh') (Join-Path $dst 'scripts') -Force
    Copy-Item (Join-Path $RepoRoot '.claude/hooks/*.sh') (Join-Path $dst '.claude/hooks/') -Force
    Copy-Item (Join-Path $RepoRoot '.claude/settings.json') (Join-Path $dst '.claude/settings.json') -Force
    Copy-Item (Join-Path $RepoRoot '.githooks/*') (Join-Path $dst '.githooks/') -Force
    Copy-Item (Join-Path $RepoRoot 'skills/universal-agentic-workflow.md') (Join-Path $dst 'skills/') -Force
    Copy-Item (Join-Path $RepoRoot '.mcp.json') (Join-Path $dst '.mcp.json') -Force
    foreach ($f in @('.editorconfig', '.markdownlint.jsonc', 'AGENTS.md')) {
        $src = Join-Path $RepoRoot $f
        if (Test-Path $src) { Copy-Item $src (Join-Path $dst $f) -Force }
    }
    Write-Host '✓  OS runtime installed: MCP baseline, meta-skill, hooks, scripts' -ForegroundColor Green
    Write-Host '   activate git hooks with: bash scripts/setup-git-hooks.sh' -ForegroundColor DarkGray
}

# ======================================================================
# 1. PROMPT TYPE (asked first, by design)
# ======================================================================

Show-Logo

do {
    Show-Menu 'What kind of prompt should this session start with?' 'Magenta'
    Option-Line '1' 'No prompt'            '- just open Claude Code'
    Option-Line '2' 'I have full docs'     '- inject the Master Initial Project Prompt (ingests your documentation, starts Phase 2 TDD)'
    Option-Line '3' 'I have an idea'       '- grill-me interview, then complete documentation, then the governed workflow'
    Option-Line 'X' 'Exit'
    Write-Host ''
    $promptChoice = Read-Host '➤  Choose (1/2/3/X)'
    if ($promptChoice -eq 'X' -or $promptChoice -eq 'x') { Write-Host 'Goodbye!' -ForegroundColor Green; exit }
    if ($promptChoice -in '1','2','3') { break }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
} while ($true)

$promptText = $null
$promptLabel = 'none (plain session)'
switch ($promptChoice) {
    '2' { $promptText = Get-MasterPrompt;      $promptLabel = 'master initial project prompt (full docs)' }
    '3' { $promptText = Get-CustomIdeaPrompt;  $promptLabel = 'custom idea -> grill -> full docs -> workflow' }
}

# ======================================================================
# 2. Provider selection
# ======================================================================

Clear-Host
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
# 3. Effort level
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
# 4. Project path + session preparation
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

Write-Host ''
Write-Host 'Preparing session...' -ForegroundColor White
Ensure-Toolkits
Install-OsRuntime -ProjectPath $projectPath

if ($promptChoice -eq '2') {
    $docs = @(Get-ChildItem -Path (Join-Path $projectPath 'docs') -Filter '*.md' -ErrorAction SilentlyContinue)
    if ($docs.Count -eq 0) {
        Write-Host '⚠  No documentation files found under docs/ - the injected prompt' -ForegroundColor Yellow
        Write-Host '   will make the agent stop and ask rather than guess.' -ForegroundColor Yellow
    } else {
        Write-Host ('✓  {0} documentation file(s) detected for ingestion' -f $docs.Count) -ForegroundColor Green
    }
}

# ======================================================================
# 5. Summary and launch (prompt pre-loaded as the first session message)
# ======================================================================

Clear-Host
Show-Logo

Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '                      🚀  Ready to Launch  🚀' -ForegroundColor White
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Prompt type'   -NoNewline -ForegroundColor White; Write-Host '   : ' -NoNewline; Write-Host $promptLabel -ForegroundColor Magenta
Write-Host 'Model'        -NoNewline -ForegroundColor White; Write-Host '        : ' -NoNewline; Write-Host $model -ForegroundColor Cyan
Write-Host 'Effort Level' -NoNewline -ForegroundColor White; Write-Host ' : ' -NoNewline; Write-Host $env:CLAUDE_CODE_EFFORT_LEVEL -ForegroundColor Yellow
Write-Host 'Path'         -NoNewline -ForegroundColor White; Write-Host '         : ' -NoNewline; Write-Host $projectPath -ForegroundColor White
Write-Host ''
Write-Host 'Press Enter to launch Claude Code...' -ForegroundColor Green
Read-Host | Out-Null

Set-Location $projectPath
Write-Host 'Launching Claude Code with ' -NoNewline; Write-Host $model -NoNewline -ForegroundColor Cyan
Write-Host (' | prompt: ' + $promptLabel) -ForegroundColor Magenta
Write-Host ''

if ($promptText) {
    $tmp = Join-Path $env:TEMP ('vantrilex-prompt-' + [guid]::NewGuid().ToString('N') + '.txt')
    [System.IO.File]::WriteAllText($tmp, $promptText + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    try {
        Get-Content -Raw -Encoding UTF8 $tmp | npx @anthropic-ai/claude-code@latest
    } finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
} else {
    npx @anthropic-ai/claude-code@latest
}
