# Changelog

All notable changes to the Universal Agentic Engineering OS are documented in this file. The format follows Keep a Changelog and versions follow Semantic Versioning.

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
