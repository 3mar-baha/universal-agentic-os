---
name: universal-agentic-workflow
description: Complete operating manual for the Universal Agentic Engineering OS — the tripartite model, the 4-phase lifecycle, 6-toolkit rotation, Orca worktree parallelism, and every safety invariant. Load once at session start to make any AI agent (Claude Code, an Orca sub-agent, Cursor, Codex) a fully governed operator of the OS.
---

# Universal Agentic Workflow

## Purpose

This is the meta-skill of the Universal Agentic Engineering OS: one document that gives any AI
agent — Claude Code, an Orca sub-agent, Cursor, Codex, or any tool-calling assistant — complete
comprehension of how the OS operates. It condenses the seven guides under `docs/`, the six core
skills under `skills/`, the scripts under `scripts/`, and the hooks under `.claude/hooks/` into a
single operational contract. Load it before touching the repository; where this skill and a guide
disagree, the guide governs and this skill is corrected (see precedence in section 7).

## When to Load

- Session start, before any other action — alongside reading `CLAUDE.md` and `docs/10-CHECKPOINT.md`.
- Whenever you lose track of which phase is active or which capabilities are injected.
- Before dispatching, merging, orchestrating, or releasing anything.

## 1. The Tripartite Operating Model

Every mission runs through exactly three roles. They are roles, not people: one agent instance may
hold several, but decision rights never merge.

| Role | Owns | Decision rights | Explicitly not theirs |
| --- | --- | --- | --- |
| **Leader** | Mission decomposition, task routing, sequencing, final accountability | Task order, scope boundaries, routing, abort authority | Signing off quality |
| **Guide** | Specification, architecture review, guardrails, quality gates; signs off every phase exit | Spec acceptance, phase-exit approval, changed-hypothesis approval, circuit-breaker invocation | Re-routing tasks |
| **Implementer** | TDD micro-cycles (red, green, refactor) inside isolated git worktrees; one concern per worktree | Technical approach within the spec, commit granularity, test structure | Widening scope or redefining acceptance criteria |

Escalation follows a fixed ladder. Strike 1: a fix hypothesis fails — log hypothesis plus evidence,
attempt a second. Strike 2: a second failure — escalate to the Guide; further unilateral attempts
are prohibited. The Guide either approves a changed hypothesis (strikes reset) or endorses one
narrowly scoped third attempt. Strike 3: HALT all execution immediately, emit a Diagnostic Incident
Report (DIR), and hand it to the Leader to re-plan or abort. Never attempt a blind fourth fix.

## 2. The 4-Phase Lifecycle and Stage Orchestration

The executable stage machine — what `ACTIVE_PHASE` in `docs/10-CHECKPOINT.md`, the session-start
hook, and `scripts/orchestrate-stage.sh` drive — has four phases:

| Phase | Name | Focus | Exit criteria |
| --- | --- | --- | --- |
| 1 | Inception & Specs | Discovery, specification drafting, Guide sign-off | Approved specs; checkpoint DAG anchored; mission recorded |
| 2 | Core Build & TDD | Red-green-refactor cycles in parallel worktrees | Full suite green; concerns merged through reviewed integrations |
| 3 | Quality Gates & Security | Guards, security review, hardening | Clean Code Guard, Test Guard, security scan all green |
| 4 | Docs Verification & Release | Docs guard, packaging, tagged release | CI green; changelog entry; tag pushed; release published |

The prose guides (`docs/00-ARCHITECTURE-GUIDE.md`, `docs/02-TOOLKIT-AND-ORCA-GUIDE.md`) use a
conceptual vocabulary for the same arc — Discover & Launch, Architect & Guide, Implement & Verify,
Harden & Release. Phase numbers always win at runtime: read `ACTIVE_PHASE`, not prose.

Stage orchestration mechanics (`scripts/orchestrate-stage.sh <1-4>`):

1. Purge all ephemeral context — `.claude/skills/*`, `.claude/agents/*`, ephemeral `stage-*.sh`
   hooks — so no stale kit from another phase survives.
2. Inject exactly that phase's skills and agents from the toolkit directory into `.claude/`.
3. Report inventory. A missing asset is a warning (upstream toolkits evolve); a missing toolkit
   directory or zero successful injections is fatal.

Never enter a phase until the Guide signs off the previous exit. Re-run orchestration after any
interruption or context compaction; applying the same phase twice must be idempotent.

## 3. 6-Toolkit Dynamic Selection and Rotation

All agent-facing capability lives outside project repositories, centralized in one directory:

```bash
CLAUDE_TOOLKIT_DIR="${CLAUDE_TOOLKIT_DIR:-$HOME/ai-agent-toolkit}"
```

Six upstream toolkits live there: `everything-claude-code`, `mattpocock-skills`, `ponytail`,
`guard-skills`, `cybersecurity-skills`, `agency-agents`. Sessions resolve assets by absolute path
under this directory and never vendor copies. Provision with `bash scripts/setup-toolkit.sh`,
refresh with `bash scripts/sync-toolkit.sh`, verify offline with `setup-toolkit.sh --verify`.

Rotation table (verified against `scripts/orchestrate-stage.sh`; source paths abbreviated to
`<KIT>` = `$CLAUDE_TOOLKIT_DIR`):

| Phase | Injected skills → `.claude/skills/` | Injected agents → `.claude/agents/` |
| --- | --- | --- |
| 1 Inception & Specs | mattpocock-skills `grill-me`, `to-spec` | agency-agents `reality-checker.md`, `product-manager.md` |
| 2 Core Build & TDD | all `<KIT>/ponytail/skills/*`; mattpocock-skills `tdd`, `diagnosing-bugs`; everything-claude-code `rules/testing.md` | ECC `tdd-guide.md`; language specialist detected from the spec text (rust specialist, else ECC `architect.md`) |
| 3 Quality Gates & Security | guard-skills `clean-code-guard`, `test-guard`; cybersecurity-skills GitHub-Advanced-Security scanning as `security-review`; ECC `rules/security.md` | ECC `security-reviewer.md` |
| 4 Docs Verification & Release | guard-skills `docs-guard`; mattpocock-skills `git-guardrails`; bundled `skills/github-release-packager.md` | — |

Pruning happens automatically on the next phase's purge — there is no separate prune step. Inject
only what the phase needs; anything not justified by phase, archetype, or detected repository
signals stays out of context.

## 4. Multi-Agent Parallel Worktrees (Orca)

Parallel Implementers never share a working tree. The milestone DAG lives in
`docs/10-CHECKPOINT.md`; each open milestone decomposes into independent workstreams.

Dispatch (`uos dispatch <stream> [phase]`, `scripts/dispatch-worktrees.sh`):

- Stream names are lowercase kebab-case; omitting one uses the slug of the first open DAG item.
- Refuses to run when the checkpoint status is `BLOCKED` (the circuit breaker owns the session),
  when staged changes exist (uncommitted state never crosses a worktree boundary), when the name
  is unsafe, or when the stream is already dispatched.
- Creates `git worktree add .worktrees/<stream> -b feature/<stream>`, injects the phase context kit
  inside the worktree, and writes `.claude/STREAM.md` — the sub-agent briefing: resume strict TDD
  immediately without confirmation prompts, one concern per worktree, integrate only via merge.

Merge (`uos merge <stream> [--keep]`, `scripts/merge-worktrees.sh`):

1. Regression gate over the stream's diff against its base: `bash -n` + shellcheck on changed shell
   scripts, markdownlint on changed markdown. Gate failure merges nothing.
2. `git merge --no-ff` so history keeps one merge commit per stream.
3. Prune worktree and branch (`--keep` retains both).
4. Stamp the checkpoint with `integrated: <stream> @ <sha> (<date>)`; milestone archiving clears
   these lines, keeping the checkpoint under 50 lines.

Refuses when BLOCKED, dirty index, unknown stream, or gate failure. Two concerns never share a
worktree; integration happens through reviewed merges only.

## 5. Invariants and Safety Gates

Nine invariants bind every role, every phase, every change (full text: `CLAUDE.md`):

1. **Specification before code** — no production code without an approved spec note.
2. **TDD always** — red, green, refactor, in that order, every cycle.
3. **Ponytail minimalism** — the smallest abstraction that satisfies the spec; delete over-abstraction on sight.
4. **Three-strike circuit breaker** — halt at three consecutive failed fix attempts; never a blind fourth.
5. **Zero secret leaks** — secrets live only in gitignored `.env`, referenced by name, never by value.
6. **Context hygiene** — prime context at session start; inject only what the phase needs.
7. **Isolation** — parallel work runs one concern per git worktree.
8. **No error swallowing** — every failure surfaces; empty catches and `|| true` on load-bearing commands are violations.
9. **Zero AI attribution** — no AI attribution anywhere in commits, files, or documents.

The machinery that enforces them:

- **Zero-prompt startup** — the `session_start` hook reads `docs/10-CHECKPOINT.md`, extracts
  `status` and `ACTIVE_PHASE`, orchestrates that phase's context kit, and prints the startup banner.
  You resume the active milestone immediately; prompting for permission on in-scope work violates
  the protocol. If status is `BLOCKED`: read the DIR, form a changed hypothesis, stop.
- **3-Strike Circuit Breaker** — the `post_tool_call` hook tracks consecutive failures of test/build
  commands in `.claude/.strike_tracker` (one strike per line; a success clears it). At strike 3 it
  writes the DIR into `docs/10-CHECKPOINT.md`, sets `status: BLOCKED`, and exits 2 to surface the
  halt. DIR contents: symptom, hypothesis log with evidence per strike, ranked root causes,
  recommended unblock actions. Strikes reset only on a Guide-approved changed hypothesis.
- **Ephemeral teardown** — the `session_end` hook / `scripts/teardown-stage.sh` remove injected
  skills and agents, ephemeral stage hooks, strike state, the spec index, and empty worktree roots.
  It never touches project code, `docs/`, or bundled `skills/`.
- **Pre-commit secret scanning** — `.githooks/pre-commit` (activate once with
  `scripts/setup-git-hooks.sh`) rejects commits containing known API-key formats
  (`sk-ant-*`, `sk-or-v1-*`, `gh*_*`, `github_pat_*`, `xox*-*`, `AKIA*`), credential-shaped
  assignments, literal `.env` files, and AI-attribution markers. Never bypass with `--no-verify`.
- **Strict zero AI attribution** — no `Co-authored-by` trailers, no "Generated with" footers, no
  agent badges; `.githooks/pre-commit` and `.githooks/commit-msg` enforce this at commit time.

## 6. Command Surface

The `uos` CLI (`scripts/uos.sh`, install with `uos install`) wraps every operation:

| Command | Effect |
| --- | --- |
| `uos ingest` | Parse and cross-reference every spec under `docs/` (read-only); write `.claude/spec-index.md` |
| `uos plan` | Print the checkpoint milestone DAG as dispatchable streams |
| `uos dispatch <stream> [phase]` | Provision an isolated worktree pre-injected with the phase kit |
| `uos merge <stream> [--keep]` | Gate, `--no-ff` merge, prune, and stamp one stream |
| `uos doctor` | Sub-second environment, hook-wiring, API-key-presence, toolkit-integrity diagnostics |
| `uos ship [--release]` | Run all local quality gates and print (or draft) the release |
| `uos status` | Compact 3-line card: phase, milestone, test state, toolkit state |

## 7. Reading Order and Precedence

Read, in order: `CLAUDE.md` → this skill → `docs/10-CHECKPOINT.md` → the routed task's documents
(`uos ingest` builds the index). When artifacts disagree:

```
CLAUDE.md invariants  >  docs guides  >  skills  >  code comments
```

A lower artifact yields and the discrepancy becomes a proposal to amend the higher one. Where this
skill and a guide disagree, the guide governs.
