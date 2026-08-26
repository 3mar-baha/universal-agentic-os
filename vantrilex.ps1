# ======================================================================
# Vantrilex - AI Coding Orchestrator (Multi-Agent, Multi-Provider)
# ======================================================================
# One interactive entry point that bootstraps a session for Claude Code,
# OpenCode, or Codex against the provider you choose:
#
#   1. Prompt type FIRST:
#        [1] No prompt      - just open the tool
#        [2] Have full docs - inject the Master Initial Project Prompt
#        [3] Custom idea    - grill-me interview -> complete documentation
#                             suite -> governed workflow
#   2. Provider (keys resolved env -> .env.vantrilex -> paste; never stored
#      in this file, always masked to the last 6 characters).
#   3. Agent: Claude Code | OpenCode | Codex - provider wiring translated
#      per tool through the pure Get-AgentPlan function (the single source
#      of truth, exercised by the -SelfTest matrix).
#   4. Session preparation: provisions the 6 toolkits when missing and
#      vendors the OS runtime (hooks, scripts, meta-skill, .mcp.json) into
#      projects that lack it.
#   5. Launches the chosen agent with the chosen prompt as first message.
#
# Self-test (offline, no keys, no network):
#   powershell -ExecutionPolicy Bypass -File vantrilex.ps1 -SelfTest
# Exit status: 0 all assertions pass; 1 one or more failed.
#
# Run:  powershell -ExecutionPolicy Bypass -File vantrilex.ps1
# ======================================================================

param(
    # Run the offline self-test matrix and exit (used by CI and humans).
    [switch]$SelfTest
)

$host.UI.RawUI.WindowTitle = 'Vantrilex - AI Coding Orchestrator'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$RepoRoot = $PSScriptRoot
if (-not $RepoRoot) { $RepoRoot = (Get-Location).Path }
$EnvFile = Join-Path (Get-Location).Path '.env.vantrilex'
$ToolkitDir = $env:CLAUDE_TOOLKIT_DIR
if (-not $ToolkitDir) { $ToolkitDir = Join-Path $env:USERPROFILE 'ai-agent-toolkit' }

$Script:ToolkitNames = @(
    'everything-claude-code',
    'mattpocock-skills',
    'ponytail',
    'guard-skills',
    'cybersecurity-skills',
    'agency-agents'
)

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
    Write-Host '  ───  AI Coding Orchestrator' -ForegroundColor Yellow
    Write-Host '======================================================================' -ForegroundColor White
    Write-Host ''
    Write-Host '🔑  Claude Code · OpenCode · Codex  ×  DeepSeek · OpenRouter · Orca · Custom' -ForegroundColor Green
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

function Warn-Combo {
    param([string]$Message)
    Write-Host ('⚠  ' + $Message) -ForegroundColor Yellow
}

# ======================================================================
# Pure logic (no IO) - the single source of truth for agent wiring.
# ======================================================================

function Get-AgentPlan {
    # Translate (agent x provider) into environment variables, CLI
    # arguments, and warnings. Pure: mutates nothing, prints nothing.
    param(
        [Parameter(Mandatory)] [ValidateSet('claude', 'opencode', 'codex')] [string]$AgentId,
        [Parameter(Mandatory)] [string]$ProviderName,
        [Parameter(Mandatory)] [string]$ModelId,
        [AllowNull()] [string]$AnthropicBase,
        [AllowNull()] [string]$OpenAIBase,
        [AllowNull()] [string]$StandardEnvVar,
        [Parameter(Mandatory)] [string]$ApiKey,
        [AllowNull()] [string]$EffortLevel
    )

    $envVars = @{}
    $launchArgs = @()
    $warnings = @()
    $agentName = ''

    switch ($AgentId) {
        'claude' {
            $agentName = 'Claude Code'
            if (-not $AnthropicBase) {
                $warnings += 'no Anthropic-wire base URL known for this provider'
            } else {
                $envVars['ANTHROPIC_BASE_URL'] = $AnthropicBase
            }
            $envVars['ANTHROPIC_AUTH_TOKEN'] = $ApiKey
            $envVars['ANTHROPIC_MODEL'] = $ModelId
            $envVars['CLAUDE_CODE_SUBAGENT_MODEL'] = $ModelId
            if ($ProviderName -like 'Ox Alpha*') {
                $envVars['ANTHROPIC_SMALL_FAST_MODEL'] = $ModelId
                $envVars['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] = '1000000'
                $envVars['CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT'] = '1'
            }
            if ($EffortLevel) { $envVars['CLAUDE_CODE_EFFORT_LEVEL'] = $EffortLevel }
        }
        'opencode' {
            $agentName = 'OpenCode'
            if ($StandardEnvVar) {
                $envVars[$StandardEnvVar] = $ApiKey
            } else {
                $warnings += 'OpenCode has no built-in provider for this endpoint; pick the model inside the TUI (/models) or add a custom provider to opencode.json'
            }
            if ($ProviderName -like 'DeepSeek*')     { $launchArgs = @('-m', 'deepseek/deepseek-chat') }
            elseif ($ProviderName -like 'Ox Alpha*') { $launchArgs = @('-m', 'openrouter/stealth/ox-alpha') }
        }
        'codex' {
            $agentName = 'Codex'
            if (-not $OpenAIBase) {
                $warnings += 'this provider has no verified OpenAI-compatible endpoint; Codex launch may fail'
            }
            $envVars['VANTRILEX_API_KEY'] = $ApiKey
            $launchArgs = @(
                '-c', 'model_providers.vantrilex.name=Vantrilex',
                '-c', ('model_providers.vantrilex.base_url=' + $OpenAIBase),
                '-c', 'model_providers.vantrilex.env_key=VANTRILEX_API_KEY',
                '-c', 'model_providers.vantrilex.wire_api=chat',
                '-c', 'model_provider=vantrilex',
                '-c', ('model=' + $ModelId)
            )
        }
    }

    [PSCustomObject]@{
        AgentName  = $agentName
        EnvVars    = $envVars
        LaunchArgs = $launchArgs
        Warnings   = $warnings
    }
}

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

function Get-ContinueProjectPrompt {
    return @"
You are resuming a governed Universal Agentic Engineering OS project that is already in flight. Sessions are zero-prompt by contract: never ask for confirmation on in-scope work. Execute in order:
1. PRIME CONTEXT: read CLAUDE.md, skills/universal-agentic-workflow.md, and docs/10-CHECKPOINT.md (status, ACTIVE_PHASE, milestone DAG). Run bash scripts/uos.sh ingest, bash scripts/uos.sh status, and bash scripts/uos.sh doctor; fix any FAIL row before building.
2. IF status IS BLOCKED: the circuit breaker has tripped. Read the recorded Diagnostic Incident Report, form ONE changed hypothesis, and stop for Guide approval - never a blind fourth fix.
3. OTHERWISE RESUME IMMEDIATELY: take the first open milestone in the DAG and continue strict TDD (red, green, refactor) exactly where the last session left off. Dispatch independent workstreams with uos dispatch <stream>; integrate only through uos merge <stream> gates; keep one concern per worktree.
4. HOUSEKEEPING AS YOU GO: archive completed milestones to docs/archive/ (checkpoint under 50 lines), update documentation and CHANGELOG in the same change as behavior, record architectural trade-offs with uos decide.
5. Phases advance only on Guide sign-off. After every milestone print compact status: phase, milestones done/remaining, risks, next action. End the session with on-disk state a fresh session resumes without asking anything.
Hold all nine invariants; tests are the contract; secrets referenced by name only; zero AI attribution anywhere.
"@
}

function Get-ToolkitCount {
    # Number of canonical toolkits present under $ToolkitDir.
    param([string]$Dir = $ToolkitDir)
    @($Script:ToolkitNames | Where-Object { Test-Path (Join-Path $Dir $_) }).Count
}

function Ensure-Toolkits {
    $count = Get-ToolkitCount
    if ($count -eq 6) {
        Write-Host '✓  toolkits present (6/6)' -ForegroundColor Green
        return
    }
    Write-Host ('⋯  toolkit inventory {0}/6; provisioning...' -f $count) -ForegroundColor Yellow
    $setup = Join-Path $RepoRoot 'scripts/setup-toolkit.sh'
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        & bash $setup
        $count = Get-ToolkitCount
        if ($count -eq 6) { Write-Host '✓  toolkits provisioned (6/6)' -ForegroundColor Green }
        else { Write-Host ('⚠  toolkit inventory still {0}/6; sessions may lack injected skills' -f $count) -ForegroundColor Red }
    } else {
        Write-Host '⚠  bash not found; run scripts/setup-toolkit.sh manually' -ForegroundColor Red
    }
}

function Install-OsRuntime {
    # Vendor the OS runtime into a project that lacks it so MCP servers,
    # skills, and hooks load directly into every session there.
    param([string]$ProjectPath)

    if ((Resolve-Path $ProjectPath).Path -eq (Resolve-Path $RepoRoot).Path) {
        Write-Host '✓  target is the OS repository itself; runtime already present' -ForegroundColor Green
        return
    }
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
# Offline self-test matrix (-SelfTest): exercises the pure wiring logic
# for every agent x provider combination without keys or network.
# ======================================================================

function Invoke-SelfTest {
    $script:failures = 0
    $script:total = 0
    $key = 'TESTKEY-1234567890abcdef'

    function Assert {
        param([string]$Name, [bool]$Condition)
        $script:total++
        if ($Condition) { Write-Host ('[selftest] ok    ' + $Name) -ForegroundColor Gray }
        else { Write-Host ('[selftest] FAIL  ' + $Name) -ForegroundColor Red; $script:failures++ }
    }

    Write-Host '[selftest] universal agentic os - vantrilex offline matrix'

    $providers = @(
        @{ name = 'DeepSeek V4 Pro';           model = 'deepseek-chat';       anth = 'https://api.deepseek.com/anthropic'; oai = 'https://api.deepseek.com/v1'; std = 'DEEPSEEK_API_KEY' },
        @{ name = 'Ox Alpha (OpenRouter)';     model = 'stealth/ox-alpha';    anth = 'https://openrouter.ai/api';          oai = 'https://openrouter.ai/api/v1'; std = 'OPENROUTER_API_KEY' },
        @{ name = 'OrcaRouter (Free Gateway)'; model = 'deepseek/deepseek-chat'; anth = 'https://api.orcarouter.ai';       oai = $null;                          std = $null },
        @{ name = 'Custom endpoint';           model = 'vendor/model-x';      anth = 'https://custom.example/v1';          oai = 'https://custom.example/v1';    std = $null }
    )

    foreach ($p in $providers) {
        foreach ($a in @('claude', 'opencode', 'codex')) {
            $plan = Get-AgentPlan -AgentId $a -ProviderName $p.name -ModelId $p.model `
                -AnthropicBase $p.anth -OpenAIBase $p.oai -StandardEnvVar $p.std `
                -ApiKey $key -EffortLevel 'high'

            Assert ("{0} x {1}: named" -f $a, $p.name) ($plan.AgentName -ne '')

            if ($a -eq 'claude') {
                Assert ("{0} x {1}: anthropic base wired" -f $a, $p.name) ($plan.EnvVars['ANTHROPIC_BASE_URL'] -eq $p.anth)
                Assert ("{0} x {1}: token + model wired" -f $a, $p.name) ($plan.EnvVars['ANTHROPIC_AUTH_TOKEN'] -eq $key -and $plan.EnvVars['ANTHROPIC_MODEL'] -eq $p.model)
                if ($p.name -like 'Ox Alpha*') {
                    Assert ("{0} x {1}: 1M-context flags" -f $a, $p.name) ($plan.EnvVars['CLAUDE_CODE_MAX_CONTEXT_TOKENS'] -eq '1000000')
                }
                Assert ("{0} x {1}: effort applied" -f $a, $p.name) ($plan.EnvVars['CLAUDE_CODE_EFFORT_LEVEL'] -eq 'high')
            }

            if ($a -eq 'opencode') {
                if ($p.std) {
                    Assert ("{0} x {1}: standard key env" -f $a, $p.name) ($plan.EnvVars[$p.std] -eq $key -and $plan.Warnings.Count -eq 0)
                } else {
                    Assert ("{0} x {1}: unmapped provider warns, no model pin" -f $a, $p.name) ($plan.Warnings.Count -ge 1 -and $plan.LaunchArgs.Count -eq 0)
                }
                if ($p.name -like 'DeepSeek*') {
                    Assert ("{0} x {1}: -m deepseek pin" -f $a, $p.name) (($plan.LaunchArgs -contains '-m') -and ($plan.LaunchArgs -contains 'deepseek/deepseek-chat'))
                }
                if ($p.name -like 'Ox Alpha*') {
                    Assert ("{0} x {1}: -m openrouter/stealth pin" -f $a, $p.name) ($plan.LaunchArgs -contains 'openrouter/stealth/ox-alpha')
                }
            }

            if ($a -eq 'codex') {
                $joined = $plan.LaunchArgs -join ' '
                Assert ("{0} x {1}: key via env indirection" -f $a, $p.name) ($plan.EnvVars['VANTRILEX_API_KEY'] -eq $key)
                if ($p.oai) {
                    Assert ("{0} x {1}: openai-compatible overrides" -f $a, $p.name) (
                        $joined.Contains('model_providers.vantrilex.base_url=' + $p.oai) -and
                        $joined.Contains('wire_api=chat') -and
                        $joined.Contains('model_provider=vantrilex') -and
                        $joined.Contains('model=' + $p.model)
                    )
                    Assert ("{0} x {1}: no warnings on supported combo" -f $a, $p.name) ($plan.Warnings.Count -eq 0)
                } else {
                    Assert ("{0} x {1}: unsupported wire warns" -f $a, $p.name) ($plan.Warnings.Count -ge 1)
                }
            }
        }
    }

    # Prompt builders.
    $master = Get-MasterPrompt
    Assert 'master prompt extracted from docs/05 (single source of truth)' ($master.Length -gt 200 -and $master -match 'Universal Agentic Engineering OS' -and $master -match 'INGEST AND VALIDATE')
    $idea = Get-CustomIdeaPrompt
    Assert 'grill-me prompt covers interview, documentation suite, and Phase 2' ($idea -match 'GRILL MY IDEA' -and $idea -match 'DOCUMENTATION SUITE' -and $idea -match 'PHASE 2')
    $cont = Get-ContinueProjectPrompt
    Assert 'continue-project prompt covers checkpoint, BLOCKED path, and TDD resume' ($cont -match 'PRIME CONTEXT' -and $cont -match 'BLOCKED' -and $cont -match 'RESUME IMMEDIATELY')

    # Toolkit inventory function is exercisable offline.
    $tc = Get-ToolkitCount -Dir (Join-Path $env:TEMP 'definitely-missing-dir')
    Assert 'toolkit inventory returns 0 for empty dir' ($tc -eq 0)

    Write-Host ('[selftest] {0} assertion(s), {1} failure(s)' -f $script:total, $script:failures)
    return $script:failures
}

if ($SelfTest) {
    exit (Invoke-SelfTest)
}

# ======================================================================
# Interactive flow (only reached without -SelfTest)
# ======================================================================

Show-Logo

do {
    Show-Menu 'What kind of prompt should this session start with?' 'Magenta'
    Option-Line '1' 'No prompt'              '- just open the coding agent'
    Option-Line '2' 'New project, full docs' '- inject the Master Initial Project Prompt (ingests your documentation, starts Phase 2 TDD)'
    Option-Line '3' 'New project, an idea'   '- grill-me interview, then complete documentation, then the governed workflow'
    Option-Line '4' 'Continue a project'     '- resume the in-flight milestone from the checkpoint (zero-prompt protocol)'
    Option-Line 'X' 'Exit'
    Write-Host ''
    $promptChoice = Read-Host '➤  Choose (1/2/3/4/X)'
    if ($promptChoice -eq 'X' -or $promptChoice -eq 'x') { Write-Host 'Goodbye!' -ForegroundColor Green; exit }
    if ($promptChoice -in '1','2','3','4') { break }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
} while ($true)

$promptText = $null
$promptLabel = 'none (plain session)'
switch ($promptChoice) {
    '2' { $promptText = Get-MasterPrompt;           $promptLabel = 'master initial project prompt (full docs)' }
    '3' { $promptText = Get-CustomIdeaPrompt;       $promptLabel = 'custom idea -> grill -> full docs -> workflow' }
    '4' { $promptText = Get-ContinueProjectPrompt;  $promptLabel = 'continue existing project (checkpoint resume)' }
}

Clear-Host
Show-Logo

do {
    Show-Menu 'Select the provider' 'Yellow'
    Option-Line '1' 'DeepSeek V4 Pro'       '(Direct API - High Reliability)'
    Option-Line '2' 'DeepSeek V4 Flash'     '(Direct API - Fastest)'
    Option-Line '3' 'OrcaRouter (Free)'     '(Gateway, 90+ free providers)'
    Option-Line '4' 'Ox Alpha (OpenRouter)' '(1M Context)'
    Option-Line 'C' 'Custom endpoint'       '(OpenAI-compatible base URL + model)'
    Option-Line 'X' 'Exit'
    Write-Host ''
    $choice = Read-Host '➤  Enter your choice (1/2/3/4/C/X)'
    if ($choice -eq 'X' -or $choice -eq 'x') { Write-Host 'Goodbye!' -ForegroundColor Green; exit }
    if ($choice -in '1','2','3','4','C','c') { break }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
    Write-Host ''
} while ($true)

$ProviderName = ''; $ModelId = ''
$AnthropicBase = $null
$OpenAIBase = $null
$StandardEnvVar = $null
$Key = $null

switch ($choice.ToLower()) {
    '1' {
        $ProviderName = 'DeepSeek V4 Pro'; $ModelId = 'deepseek-chat'
        $AnthropicBase = 'https://api.deepseek.com/anthropic'
        $OpenAIBase = 'https://api.deepseek.com/v1'
        $StandardEnvVar = 'DEEPSEEK_API_KEY'
        $Key = Get-Credential-Value 'DEEPSEEK_API_KEY' 'paste your DeepSeek key'
    }
    '2' {
        $ProviderName = 'DeepSeek V4 Flash'; $ModelId = 'deepseek-chat'
        $AnthropicBase = 'https://api.deepseek.com/anthropic'
        $OpenAIBase = 'https://api.deepseek.com/v1'
        $StandardEnvVar = 'DEEPSEEK_API_KEY'
        $Key = Get-Credential-Value 'DEEPSEEK_API_KEY' 'paste your DeepSeek key'
    }
    '3' {
        $ProviderName = 'OrcaRouter (Free Gateway)'; $ModelId = 'deepseek/deepseek-chat'
        $AnthropicBase = 'https://api.orcarouter.ai'
        $OpenAIBase = $null
        $StandardEnvVar = $null
        $Key = Get-Credential-Value 'ORCA_API_KEY' 'paste your Orca gateway key'
    }
    '4' {
        $ProviderName = 'Ox Alpha (OpenRouter)'; $ModelId = 'stealth/ox-alpha'
        $AnthropicBase = 'https://openrouter.ai/api'
        $OpenAIBase = 'https://openrouter.ai/api/v1'
        $StandardEnvVar = 'OPENROUTER_API_KEY'
        $Key = Get-Credential-Value 'OPENROUTER_API_KEY' 'paste your OpenRouter key (sk-or-v1-...)'
    }
    'c' {
        $ProviderName = 'Custom endpoint'
        $url = Read-Host '➤  Base URL (OpenAI-compatible, incl. /v1)'
        if (-not $url) { Write-Host 'Base URL required.' -ForegroundColor Red; exit }
        $ModelId = Read-Host '➤  Model id (e.g. vendor/model-name)'
        if (-not $ModelId) { Write-Host 'Model id required.' -ForegroundColor Red; exit }
        $AnthropicBase = $url
        $OpenAIBase = $url
        $StandardEnvVar = $null
        $Key = Get-Credential-Value 'CUSTOM_API_KEY' 'paste the endpoint API key'
    }
}
if (-not $Key) { Write-Host 'No key provided.' -ForegroundColor Red; exit }

Clear-Host
Show-Logo

do {
    Show-Menu 'Select the coding agent to launch' 'Cyan'
    Option-Line '1' 'Claude Code'  '(npx @anthropic-ai/claude-code)'
    Option-Line '2' 'OpenCode'     '(npx opencode-ai)'
    Option-Line '3' 'Codex'        '(npx @openai/codex)'
    Option-Line 'B' 'Back'         '- return to provider menu'
    Option-Line 'X' 'Exit'
    Write-Host ''
    $agentChoice = Read-Host '➤  Enter your choice (1/2/3/B/X)'
    if ($agentChoice -eq 'X' -or $agentChoice -eq 'x') { Write-Host 'Goodbye!' -ForegroundColor Green; exit }
    if ($agentChoice -eq 'B' -or $agentChoice -eq 'b') { & $MyInvocation.MyCommand.Path; exit }
    if ($agentChoice -in '1','2','3') { break }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
} while ($true)

$AgentMap = @{ '1' = 'claude'; '2' = 'opencode'; '3' = 'codex' }

do {
    Show-Menu 'Select Effort Level' 'Blue'
    Option-Line '1' 'Low'       '- Fastest responses, lower token usage'
    Option-Line '2' 'Medium'    '- Balanced speed and quality'
    Option-Line '3' 'High'      '- High quality, deeper reasoning'
    Option-Line '4' 'XHigh'     '- Extra deep reasoning'
    Option-Line '5' 'Max'       '- Maximum reasoning quality'
    Option-Line '6' 'Ultracode' '- Multi-agent dynamic workflow orchestration'
    Option-Line 'B' 'Back'      '- Return to agent menu'
    Write-Host ''
    $effort = Read-Host '➤  Enter the level number (1-6/B)'
    if ($effort -eq 'B' -or $effort -eq 'b') { & $MyInvocation.MyCommand.Path; exit }
    if ($effort -match '^[1-6]$') {
        $effortMap = @{ '1'='low'; '2'='medium'; '3'='high'; '4'='xhigh'; '5'='max'; '6'='ultracode' }
        $EffortLevel = $effortMap[$effort]
        break
    }
    Write-Host 'Invalid choice, please try again.' -ForegroundColor Red
} while ($true)

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

$Plan = Get-AgentPlan -AgentId $AgentMap[$agentChoice] -ProviderName $ProviderName -ModelId $ModelId `
    -AnthropicBase $AnthropicBase -OpenAIBase $OpenAIBase -StandardEnvVar $StandardEnvVar `
    -ApiKey $Key -EffortLevel $EffortLevel
foreach ($k in $Plan.EnvVars.Keys) { Set-Item -Path ("env:{0}" -f $k) -Value $Plan.EnvVars[$k] }
foreach ($w in $Plan.Warnings) { Warn-Combo $w }

if ($promptChoice -eq '2') {
    $docs = @(Get-ChildItem -Path (Join-Path $projectPath 'docs') -Filter '*.md' -ErrorAction SilentlyContinue)
    if ($docs.Count -eq 0) {
        Write-Host '⚠  No documentation files found under docs/ - the injected prompt' -ForegroundColor Yellow
        Write-Host '   will make the agent stop and ask rather than guess.' -ForegroundColor Yellow
    } else {
        Write-Host ('✓  {0} documentation file(s) detected for ingestion' -f $docs.Count) -ForegroundColor Green
    }
}

$effortDisplay = $EffortLevel
if ($AgentMap[$agentChoice] -ne 'claude' -and $EffortLevel) { $effortDisplay = "$EffortLevel (recorded; effort env is Claude Code-specific)" }

Clear-Host
Show-Logo

Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host '                      🚀  Ready to Launch  🚀' -ForegroundColor White
Write-Host '═══════════════════════════════════════════════════════════════' -ForegroundColor Cyan
Write-Host ''
Write-Host 'Agent'         -NoNewline -ForegroundColor White; Write-Host '         : ' -NoNewline; Write-Host $Plan.AgentName -ForegroundColor Cyan
Write-Host 'Prompt type'   -NoNewline -ForegroundColor White; Write-Host '   : ' -NoNewline; Write-Host $promptLabel -ForegroundColor Magenta
Write-Host 'Provider'      -NoNewline -ForegroundColor White; Write-Host '      : ' -NoNewline; Write-Host $ProviderName -ForegroundColor Cyan
Write-Host 'Effort Level'  -NoNewline -ForegroundColor White; Write-Host ' : ' -NoNewline; Write-Host $effortDisplay -ForegroundColor Yellow
Write-Host 'Path'          -NoNewline -ForegroundColor White; Write-Host '         : ' -NoNewline; Write-Host $projectPath -ForegroundColor White
if ($Plan.LaunchArgs.Count -gt 0) {
    Write-Host 'Model pinning' -NoNewline -ForegroundColor White; Write-Host '  : ' -NoNewline; Write-Host ($Plan.LaunchArgs -join ' ') -ForegroundColor DarkGray
}
Write-Host ''
Write-Host 'Press Enter to launch...' -ForegroundColor Green
Read-Host | Out-Null

Set-Location $projectPath
Write-Host 'Launching ' -NoNewline; Write-Host $Plan.AgentName -NoNewline -ForegroundColor Cyan
Write-Host (' | ' + $ProviderName + ' | prompt: ' + $promptLabel) -ForegroundColor Magenta
Write-Host ''

$AllArgs = @($Plan.LaunchArgs)
if ($promptText) { $AllArgs += $promptText }

switch ($AgentMap[$agentChoice]) {
    'claude'   { & npx '@anthropic-ai/claude-code@latest' @AllArgs }
    'opencode' { & npx 'opencode-ai@latest' @AllArgs }
    'codex'    { & npx '@openai/codex@latest' @AllArgs }
}
