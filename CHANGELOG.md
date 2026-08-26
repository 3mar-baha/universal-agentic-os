# Changelog

All notable changes to the Universal Agentic Engineering OS are documented in this file. The format follows Keep a Changelog and versions follow Semantic Versioning.

## [1.4.0] - 2026-08-26

The usability release: every common journey collapses to one command — machine setup, project creation, and agent entry.

### Added

- `scripts/init.sh` + `uos init`: one-command machine bootstrap. Provisions and verifies the 6-toolkit directory, activates git hooks, installs the CLI onto PATH, prints the `CLAUDE_TOOLKIT_DIR` export hint when unset, and finishes with a full `uos doctor` report. Idempotent.
- `scripts/new-project.sh` + `uos new <NAME> [DIR]`: scaffolds a brand-new governed project — the canonical 16-file hierarchy with real seed content, the live `docs/10-CHECKPOINT.md`, and a vendored OS runtime (native hooks + settings, all lifecycle scripts, the Universal Meta-Skill, `.mcp.json`, lint config) — then initializes git with a clean first commit. The result is immediately ready for the master initial prompt.
- `AGENTS.md` at the repository root: a four-item entry point for agents other than Claude Code (Cursor, Codex, Windsurf) — constitution, meta-skill, checkpoint protocol, command surface.
- Guided `uos help`: commands grouped into Setup & Diagnosis / Daily Loop / Governance & Release, with FIRST TIME? and START A PROJECT? pointers at the top.

### Changed

- README quick starts (English and Arabic) collapse from four setup steps to `uos init`.
- The architecture guide's repository map includes `AGENTS.md`.

## [1.3.1] - 2026-08-26

Six small gates and one big shortcut — each closes a gap observed in practice during the v1.2.0/v1.3.0 ships.

### Added

- `scripts/release.sh` + `uos release <X.Y.Z> [--draft]`: one-command publishing. Validates the version, extracts its CHANGELOG section as the release notes (nothing invented), refuses on a dirty tree or an existing tag, then tags, pushes, and creates the GitHub release via `gh`.
- `.github/workflows/release.yml`: on any `v*` tag push, packages the source tarball (now including `.mcp.json` and `.devcontainer/`) and attaches it to the GitHub release; self-heals if the tag lands before the release is created.
- `uos ship` gains two gates: version consistency (CHANGELOG head must equal both README badges and the CLI's own version) and architecture-graph currency (`generate-graph.sh --check`).
- `uos doctor` now checks for `uvx`, which runs two of the five pinned MCP servers (`fetch`, `git`); its absence previously failed those servers silently at session time.

### Changed

- `.githooks/pre-commit`: bearer tokens in JSON/YAML-style `Authorization` headers are now rejected alongside known API-key formats, closing a real scan gap for MCP-style configs.
- READMEs document the new command and gates; the meta-skill reflects the extended secret scanning.

## [1.3.0] - 2026-08-26

Level-3 agentic maturity: pinned MCP protocol, upstream ECC lifecycle integration, a live architecture graph, an automated ADR ledger, and one-command sandbox parity.

### Added

- `.mcp.json`: turnkey protocol enforcement pinning five core MCP servers — `fetch`, `brave-search`, `sequential-thinking`, `filesystem`, `git` — committed with placeholders only; credentials referenced by environment variable name (`BRAVE_API_KEY`), never value.
- `scripts/generate-graph.sh` + `uos graph [--check]`: live Mermaid sync engine. Scans the repo's top-level structure (tracked-file counts only, so ephemeral injected context never stales the graph) and synchronizes it into the architecture document between `uos:graph:start/end` markers; auto-detects `docs/04-ARCHITECTURE.md` (16-doc suite layout), `docs/01-ARCHITECTURE.md` (canonical scaffold), or `docs/00-ARCHITECTURE-GUIDE.md` (this repository). Regeneration is byte-idempotent; `--check` exits 1 on stale graphs.
- `scripts/record-decision.sh` + `uos decide <TITLE> [--status|--context|--decision|--consequences]`: append-only ADR ledger auto-detected at `docs/09-DECISIONS.md` or `docs/03-DECISIONS.md` (created with the canonical header on first use); seeded with this release's three architecture records.
- Upstream ECC lifecycle-hook integration: `scripts/orchestrate-stage.sh` now vendors everything-claude-code's dependency-free bash hooks (`session-start`, `session-end`, `pre-compact`, `suggest-compact`) into ephemeral `.claude/hooks/ecc/` on every phase; the native `session_start` hook surfaces ECC context in its banner and the native `session_end` hook persists session memory before teardown removes the vendored copies. Dispatched worktrees run their own orchestration, so propagation to parallel Implementers is automatic.
- `.devcontainer/`: tailored Ubuntu 24.04 Dockerfile (shellcheck, jq) plus `devcontainer.json` with Node LTS and GitHub CLI features and a `postCreateCommand` that provisions all 6 toolkits and activates git hooks.
- CI: graph-sync idempotency/staleness and ADR-ledger append covered by the Test job.

### Changed

- `uos` CLI is now v1.3.0: new `graph` and `decide` commands documented in both READMEs.
- `skills/universal-agentic-workflow.md` documents the human-Leader instantiation of the tripartite model, the ECC hook machinery, the MCP baseline, sandbox parity, and the new commands; reading order covers the 16-doc specification-suite layout.
- `docs/05-INITIAL-PROMPT.md` now serves both specification layouts: OS-guide repositories and 16-doc spec-suite projects, with per-document extraction targets (stack from 03, milestone DAG from 07, threat model from 12, …), DAG seeding from `07-IMPLEMENTATION-PLAN.md`, and archive-first checkpoint anchoring.

## [1.2.0] - 2026-08-26

The Universal Meta-Skill and the turnkey master initial project prompt — any AI agent, in any harness, now reaches full operating comprehension of the OS from two artifacts.

### Added

- `skills/universal-agentic-workflow.md`: the Universal Meta-Skill (Agent Skills Standard). One document giving any AI agent — Claude Code, Orca sub-agents, Cursor, Codex — complete comprehension of the OS: the tripartite Leader/Guide/Implementer model with its escalation ladder, the executable 4-phase lifecycle and stage orchestration mechanics, the 6-toolkit dynamic selection and rotation table, multi-agent parallel worktrees (DAG decomposition, `.worktrees/` isolation, merge gates), and all nine invariants with their enforcing machinery.
- `docs/05-INITIAL-PROMPT.md` upgraded to the turnkey master initial project prompt: verifies the 6 upstream toolkits in `$HOME/ai-agent-toolkit` (fail closed), ingests and validates every pre-existing specification under `docs/` read-only without overwriting them, delegates workflow comprehension to the Universal Meta-Skill, auto-generates the project-tailored `CLAUDE.md` (autonomous startup protocol, TDD always, ponytail minimalism, zero AI attribution), wires `.claude/hooks/`, `scripts/`, git hooks, and the `uos` CLI, anchors `docs/10-CHECKPOINT.md` with a resumable milestone DAG, and begins Phase 2 (Core Build & TDD) immediately with zero confirmation prompts.

### Changed

- Enhanced the `uos` CLI (now v1.2.0): `uos doctor` verifies that every hook script registered in `.claude/settings.json` exists on disk, and `uos status` reports the Orca worktree-pool state (`POOL: N stream(s)`) alongside test and toolkit state — dispatched streams are visible to the Leader at a glance.
- READMEs (English and Arabic) document the seventh core skill and the enhanced initial-prompt workflow; version badges bumped to 1.2.0.
- `docs/00-ARCHITECTURE-GUIDE.md` maps the repository onto the seven-skill set and names the meta-skill as the agent-facing entry point to its model.

### Fixed

- `scripts/ingest-specs.sh` dropped the leading parenthesis when resolving markdown link targets, so any valid relative link in a specification was flagged as broken; targets are now parsed correctly.

## [1.1.0] - 2026-08-25

Native hooks architecture, deterministic stage orchestration, and CI hardening — the OS now runs its own lifecycle machinery on itself.

### Added

- Native Claude Code hooks under `.claude/hooks/`, registered in `.claude/settings.json`: `session_start.sh` (checkpoint-driven phase orchestration + startup banner), `post_tool_call.sh` (three-strike circuit breaker writing Diagnostic Incident Reports into `docs/10-CHECKPOINT.md` and halting with exit 2), `session_end.sh` (ephemeral teardown).
- `scripts/orchestrate-stage.sh`: purges ephemeral context, then injects exactly one lifecycle phase's skills/agents from the 6 canonical toolkits; language-specialist detection for the build phase.
- `scripts/uos.sh`: unified developer CLI (`uos ingest | plan | dispatch | merge | doctor | ship | status | install`) wrapping every lifecycle script, with sub-second environment diagnostics and gated release preparation.
- `scripts/ingest-specs.sh`: read-only spec ingestion — parses every document under `docs/`, cross-references links and script mentions, guards duplicate numbering, anchors the checkpoint DAG, and writes an ephemeral `.claude/spec-index.md` for agent context priming.
- `scripts/dispatch-worktrees.sh` + `scripts/merge-worktrees.sh`: Orca-style parallel streams — isolated git worktrees per workstream (refused when BLOCKED or dirty), diff-scoped regression gates, `--no-ff` integration, and automatic pruning.
- `scripts/teardown-stage.sh`: ephemeral cleanup of injected skills/agents, stage hooks, and strike state.
- `.githooks/pre-commit` + `.githooks/commit-msg`: secret scanning (known API-key formats, credential assignments, `.env`) and zero-AI-attribution enforcement; activated with `scripts/setup-git-hooks.sh`.
- `docs/10-CHECKPOINT.md`: live session state (`ACTIVE_PHASE`, milestone DAG) with completed milestones archived under `docs/archive/`.
- CI: fixture-driven Test job (phase rotations, circuit-breaker unit checks) and Build job (integrity gates + release artifact); `.editorconfig`.

### Changed

- `scripts/setup-toolkit.sh`: new `--verify` mode — offline check that all 6 toolkits are present, complete, and unmutated.
- `CLAUDE.md`: Autonomous Session Protocol added; new invariants 8 (No Error Swallowing) and 9 (Zero AI Attribution).

### Fixed

- `printf` separator lines crashed with `invalid option` in both toolkit scripts' summaries.

## [1.0.0] - 2026-08-23

Initial release of the Universal Agentic Engineering OS — a production-grade, multi-domain autonomous development and AI agent orchestration framework.

### Added

- Repository scaffold: root governance files (`LICENSE`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `.gitignore`, `.gitattributes`, `.env.example`) plus `skills/`, `scripts/`, and `.github/workflows/`.
- 7 documentation guides under `docs/`: `00-ARCHITECTURE-GUIDE.md` through `06-ENGINEERING-PILLARS.md`.
- 6 core skills: `agentic-project-launcher`, `claude-stage-orchestrator`, `session-context-primer`, `circuit-breaker-guard`, `preflight-system-doctor`, `github-release-packager`.
- 2 toolkit automation scripts: `scripts/setup-toolkit.sh` and `scripts/sync-toolkit.sh`, managing the 6 upstream toolkits in `CLAUDE_TOOLKIT_DIR` (default `~/ai-agent-toolkit`).
- CI workflow at `.github/workflows/ci.yml`.
- Bilingual documentation: English `README.md` plus full Arabic `README.ar.md`.
