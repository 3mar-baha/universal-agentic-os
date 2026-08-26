# AGENTS.md

Entry point for any AI agent (Cursor, Codex, Windsurf, or any tool-calling
assistant) working in this repository. Read these four things before acting:

1. `CLAUDE.md` — the engineering constitution: nine non-negotiable invariants.
2. `skills/universal-agentic-workflow.md` — the complete operating manual:
   tripartite Leader/Guide/Implementer model, the 4-phase lifecycle
   (Inception & Specs → Core Build & TDD → Quality Gates & Security → Docs
   Verification & Release), toolkit rotation, worktree parallelism, safety gates.
3. `docs/10-CHECKPOINT.md` — live state. If `status: ACTIVE`, resume the open
   milestone immediately with strict TDD; do not ask for confirmation on
   in-scope work. If `status: BLOCKED`, read the recorded DIR and stop.
4. `bash scripts/uos.sh help` — the command surface (`uos init`, `uos new`,
   `plan | dispatch | merge | graph | decide | doctor | ship | release`).

Hard rules that apply to every change:

- Specification before code; tests written first (red-green-refactor).
- Three-strike circuit breaker: halt after 3 consecutive failed fixes; never
  a blind fourth attempt.
- Secrets referenced by name only; never printed or committed.
- Zero AI attribution anywhere — no attribution trailers or footers.
