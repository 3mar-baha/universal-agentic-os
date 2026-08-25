# Milestone 01 — Native Hooks, Deterministic Orchestration & CI Hardening

**Completed**: 2026-08-25 · **Phase span**: all four · **Status**: shipped

## What Shipped

- **Native Claude Code hooks** (`.claude/hooks/`, registered in `.claude/settings.json`):
  - `session_start.sh` — reads `ACTIVE_PHASE` from `docs/10-CHECKPOINT.md`, orchestrates the phase kit, emits the startup banner; surfaces `BLOCKED` state.
  - `post_tool_call.sh` — circuit-breaker interceptor: tracks consecutive test/build failures in `.claude/.strike_tracker`; strike 3 writes a Diagnostic Incident Report into the checkpoint and halts with exit 2. Extraction tiers: jq → node → regex fallback.
  - `session_end.sh` — runs ephemeral teardown before session exit.
- **Deterministic orchestration**: `scripts/orchestrate-stage.sh` purges ephemeral context then injects exactly one phase's skills/agents from the 6 verified toolkits (`--verify` added to `scripts/setup-toolkit.sh`); `scripts/teardown-stage.sh` restores phase-neutrality.
- **Git hooks**: `.githooks/pre-commit` (API-key patterns + credential-assignment heuristic + `.env` rejection + AI-attribution scan) and `.githooks/commit-msg` (zero AI attribution in messages); activated via `scripts/setup-git-hooks.sh`.
- **CI hardening**: `ci.yml` gained a fixture-driven Test job (phase rotations + circuit-breaker unit checks) and a Build job (integrity gates + release artifact).

## Verification

- `setup-toolkit.sh --verify`: 6/6 toolkits present and unmutated.
- Live rotations: phases 1→4 each injected their full kit, teardown cleaned it.
- Circuit breaker exercised to strike 3 locally (DIR written, status flipped, exit 2).
